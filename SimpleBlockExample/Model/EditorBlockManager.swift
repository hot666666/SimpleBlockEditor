//
//  EditorBlockManager.swift
//  SimpleBlockExample
//
//  Created by hs on 11/1/25.
//

import Foundation
import Observation

/// 블록 리스트와 편집 명령을 총괄하는 Observable 편집 관리자입니다.
@Observable
final class EditorBlockManager {
  /// 키 입력을 편집 명령으로 해석하는 정책 객체입니다.
  @ObservationIgnored private let policy: any BlockEditingPolicy
  /// 외부 스토리지와 동기화를 담당하는 블록 스토어입니다.
  @ObservationIgnored private let store: BlockStore?
  /// Observation 의존성을 강제로 깨우기 위한 이벤트 시계입니다.
  private var nodeEventClock: UInt64 = 0

  /// 스토어 초기화를 수행하는 백그라운드 태스크입니다.
  @ObservationIgnored private var bootstrapTask: Task<Void, Never>?
  /// 현재 편집 중인 블록 노드 배열입니다.
  @ObservationIgnored private var nodes: [BlockNode] = [.init(kind: .paragraph, text: "")]
  /// 포커스를 보유한 노드의 식별자입니다.
  @ObservationIgnored private var focusedNodeID: UUID?
  /// 뷰가 처리해야 할 대기 중 블록 이벤트 목록입니다.
  @ObservationIgnored private var pendingNodeEvents: [EditorBlockEvent] = []

  init(
    store: BlockStore? = DefaultBlockStore(),
    policy: any BlockEditingPolicy = DefaultBlockEditingPolicy()
  ) {
    self.policy = policy
    self.store = store

    bootstrapTask = Task {
      await bootstrapStore()
    }
  }

  deinit {
    bootstrapTask?.cancel()
    bootstrapTask = nil
  }

  /// 최초 로딩된 노드들을 순회하면서 뷰 초기화를 돕습니다.
  func forEachInitialNode(_ body: (Int, BlockNode) -> Void) {
    nodes.enumerated().forEach(body)
  }

  /// 키 입력 이벤트에 대응하는 편집 명령을 생성합니다.
  func editCommand(for event: EditorKeyEvent, node: BlockNode) -> EditorCommand? {
    policy.makeEditorCommand(for: event, node: node, in: self)
  }

  /// 명령이 요청한 포커스 변화를 적용합니다.
  func applyFocusChange(from command: EditorCommand) {
    guard let focus = command.requestFocusChange else { return }
    applyFocusChange(focus)
  }

  /// 직접 전달된 포커스 이벤트를 반영하고 노티를 발행합니다.
  func applyFocusChange(_ focus: EditorFocusEvent) {
    switch focus {
    case .otherNode(let id, _):
      focusedNodeID = id
    case .clear:
      focusedNodeID = nil
    }
    enqueueFocusEvent(focus)
  }

  /// 노드를 끝에 추가하고 스토어에도 반영합니다.
  func appendNode(_ node: BlockNode) {
    insert(node, at: nodes.count, emitStoreEvent: true)
  }

  /// 누적된 블록 이벤트를 한 번에 방출하고 클럭을 새로 고칩니다.
  func observeNodeEvents() -> [EditorBlockEvent] {
    // withObservationTracking 내에서 access를 호출하여 클럭에 대한 의존성을 기록한다.
    access(keyPath: \.nodeEventClock)
    if pendingNodeEvents.isEmpty { return [] }
    let events = pendingNodeEvents
    pendingNodeEvents.removeAll()
    return events
  }
}

extension EditorBlockManager {
  /// 새로운 노드 이벤트를 큐에 추가하고 관찰자에게 변경을 알립니다.
  fileprivate func enqueueNodeEvent(_ event: EditorBlockEvent) {
    pendingNodeEvents.append(event)
    withMutation(keyPath: \.nodeEventClock) {
      // 오버플로 시 UInt64 &+ 연산으로 자동 래핑된다.
      nodeEventClock &+= 1
    }
  }

  /// 포커스 변경 이벤트를 전용 래퍼로 발행합니다.
  fileprivate func enqueueFocusEvent(_ change: EditorFocusEvent) {
    enqueueNodeEvent(.focus(change))
  }
}

// MARK: - Store bootstrap

extension EditorBlockManager {
	/// 외부 스토어에서 초기 데이터를 불러오고 갱신 스트림을 구독합니다.
	fileprivate func bootstrapStore() async {
		guard let store = store else { return }
		
		let initial = await store.load()
		
		await MainActor.run {
			if initial.isEmpty {
				sendStoreEvent(.replaced(nodes))
			} else {
				self.nodes = initial
			}
		}
		
		for await event in store.updates() {
			await MainActor.run {
				self.handleExternal(event)
			}
		}
	}
}

extension EditorBlockManager {
  /// 외부 스토어에 편집 이벤트를 전송합니다.
  fileprivate func sendStoreEvent(_ event: BlockStoreEvent) {
    guard let store else { return }
    Task {
      await store.apply(event)
    }
  }

  /// 외부에서 전달된 스토어 이벤트를 로컬 상태와 동기화합니다.
  fileprivate func handleExternal(_ event: BlockStoreEvent) {
    switch event {
    case .inserted(let node, at: let index):
      insert(node, at: index, emitStoreEvent: false)

    case .updated(let node, at: let index):
      update(node, at: index, emitStoreEvent: false)

    case .removed(let node, at: let index):
      remove(node, at: index, emitStoreEvent: false)

    case .merged(let source, let target):
      remove(source, at: nil, emitStoreEvent: false)
      update(target, at: nil, emitStoreEvent: false)

    case .replaced(let newNodes):
      nodes = newNodes
    }
  }

  /// 지정된 위치에 노드를 삽입하고 필요 시 스토어 이벤트를 발행합니다.
  fileprivate func insert(_ node: BlockNode, at index: Int, emitStoreEvent: Bool) {
    let clamped = max(0, min(index, nodes.count))
    nodes.insert(node, at: clamped)
    enqueueNodeEvent(.insert(node: node, index: clamped))

    if emitStoreEvent {
      sendStoreEvent(.inserted(node, at: clamped))
    }
  }

  /// 노드 내용을 갱신하고 연관된 이벤트를 전파합니다.
  fileprivate func update(_ node: BlockNode, at indexHint: Int?, emitStoreEvent: Bool) {
    let idx = indexHint ?? index(ofNodeID: node.id)
    guard let idx else { return }

    nodes[idx].kind = node.kind
    nodes[idx].text = node.text
    nodes[idx].listNumber = node.listNumber
    enqueueNodeEvent(.update(node: nodes[idx], index: idx))

    if emitStoreEvent {
      sendStoreEvent(.updated(nodes[idx], at: idx))
    }
  }

  /// 노드를 제거하고 삭제 사실을 통지합니다.
  fileprivate func remove(_ node: BlockNode, at indexHint: Int?, emitStoreEvent: Bool) {
    let idx = indexHint ?? index(ofNodeID: node.id)
    guard let idx else { return }

    let removed = nodes.remove(at: idx)
    enqueueNodeEvent(.remove(node: removed, index: idx))
    if emitStoreEvent {
      sendStoreEvent(.removed(removed, at: idx))
    }
  }

  /// 주어진 식별자를 가진 노드의 인덱스를 반환합니다.
  fileprivate func index(ofNodeID id: UUID) -> Int? {
    nodes.firstIndex(where: { $0.id == id })
  }

  /// 노드 단일 항목이 갱신되었음을 노티파이합니다.
  fileprivate func sendUpdate(forNodeID nodeID: UUID) {
    guard let idx = index(ofNodeID: nodeID) else { return }
    let node = nodes[idx]
    enqueueNodeEvent(.update(node: node, index: idx))
    sendStoreEvent(.updated(node, at: idx))
  }
}

// MARK: - BlockEditingContextProtocol

extension EditorBlockManager: BlockEditingContextProtocol {
  /// 주어진 노드의 현재 인덱스를 조회합니다.
  func index(of node: BlockNode) -> Int? {
    index(ofNodeID: node.id)
  }

  /// 이전 형제 노드를 반환합니다.
  func previousNode(of node: BlockNode) -> BlockNode? {
    guard let idx = index(of: node), idx > 0 else { return nil }
    return nodes[idx - 1]
  }

  /// 다음 형제 노드를 반환합니다.
  func nextNode(of node: BlockNode) -> BlockNode? {
    guard let idx = index(of: node), idx < nodes.count - 1 else { return nil }
    return nodes[idx + 1]
  }

  /// 외부 요청에 따라 노드를 삽입합니다.
  func insertNode(_ node: BlockNode, at index: Int) {
    insert(node, at: index, emitStoreEvent: true)
  }

  /// 인덱스 위치의 노드를 제거합니다.
  func removeNode(at index: Int) {
    guard nodes.indices.contains(index) else { return }
    let node = nodes[index]
    remove(node, at: index, emitStoreEvent: true)
  }

  /// 노드 내용이 수정되었음을 수동으로 알립니다.
  func notifyUpdate(of node: BlockNode) {
    guard let idx = index(of: node) else { return }
    enqueueNodeEvent(.update(node: nodes[idx], index: idx))
    sendStoreEvent(.updated(nodes[idx], at: idx))
  }

  /// 두 노드 병합 사실을 스토어에 전달합니다.
  func notifyMerge(from source: BlockNode, into target: BlockNode) {
    sendStoreEvent(.merged(source: source, target: target))
  }
}
