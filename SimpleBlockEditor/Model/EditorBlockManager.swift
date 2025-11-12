//
//  EditorBlockManager.swift
//  SimpleBlockEditor
//
//  Created by hs on 11/1/25.
//

import Foundation
import Observation

// MARK: - NodeMutationOrigin

/// 노드 변형이 어디에서 비롯됐는지 나타내는 내부 구분자입니다.
fileprivate enum NodeMutationOrigin {
  case localPolicy
  case externalStore
}

// MARK: - EditorBlockManager

/// 블록 리스트와 편집 명령을 총괄하는 Observable 편집 관리자입니다.
@Observable
final class EditorBlockManager {
  /// 키 입력을 편집 명령으로 해석하는 정책 객체입니다.
  @ObservationIgnored private let policy: any BlockEditingPolicy
  /// 외부 스토리지와 동기화를 담당하는 블록 스토어입니다.
  @ObservationIgnored private let store: BlockStore?
  /// Observation 의존성을 강제로 깨우기 위한 이벤트 관련 변수입니다.
  private var nodeEventClock: UInt64 = 0

  /// 스토어 업데이트 스트림을 수신하는 태스크입니다.
  @ObservationIgnored private var storeUpdatesTask: Task<Void, Never>?
  /// 최초 스토어 스냅샷 로딩 여부입니다.
  @ObservationIgnored private var hasLoadedInitialStoreSnapshot = false
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

  }

  deinit {
    storeUpdatesTask?.cancel()
    storeUpdatesTask = nil
  }
	
	/// 스토어 동기화를 시작하고 데이터 업데이트를 감지합니다.
	@MainActor
	func startStoreSync() async {
		guard let store else { return }
		
		if !hasLoadedInitialStoreSnapshot {
			let initial = await store.load()
			applyInitialStoreSnapshot(initial)
			hasLoadedInitialStoreSnapshot = true
		}
		
		guard storeUpdatesTask == nil else { return }
		storeUpdatesTask = Task { [weak self, store] in
			guard let self else { return }
			await self.consumeStoreUpdates(from: store)
		}
	}
	
	/// 스토어 업데이트 스트림 구독을 중단합니다.
	func stopStoreSync() {
		storeUpdatesTask?.cancel()
		storeUpdatesTask = nil
	}

  /// 최초 로딩된 노드들을 순회하면서 뷰 초기화를 돕습니다.
  func forEachInitialNode(_ body: (Int, BlockNode) -> Void) {
    nodes.enumerated().forEach(body)
  }

  /// 키 입력 이벤트에 대응하는 편집 명령을 생성합니다.
  func command(for event: EditorKeyEvent, node: BlockNode) -> EditorCommand? {
    policy.makeEditorCommand(for: event, node: node, in: self)
  }

  /// 직접 전달된 포커스 이벤트를 반영하고 알림을 발행합니다.
  func applyFocusChange(_ focus: EditorFocusEvent) {
    switch focus {
    case .otherNode(let id, _):
      focusedNodeID = id
    case .clear:
      focusedNodeID = nil
    }
    enqueueFocusEvent(focus)
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

// MARK: - Store heplers

extension EditorBlockManager {
  /// 초기 스냅샷을 적용하거나, 비어 있다면 현재 노드를 스토어에 전파합니다.
  fileprivate func applyInitialStoreSnapshot(_ initial: [BlockNode]) {
    if initial.isEmpty {
      sendStoreEvent(.replaced(nodes))
    } else {
      nodes = initial
    }
  }

  /// 스토어 업데이트 스트림을 소비하면서 로컬 상태를 갱신합니다.
  fileprivate func consumeStoreUpdates(from store: BlockStore) async {
    for await event in store.updates() {
        await handleExternal(event)
    }
  }
	
	/// 외부 스토어에 편집 이벤트를 전송합니다.
	fileprivate func sendStoreEvent(_ event: BlockStoreEvent) {
		guard let store else { return }
		Task {
			await store.apply(event)
		}
	}

	/// 스토어 이벤트 발행이 필요한 경우에만 외부에 전달합니다.
	fileprivate func publishStoreEvent(_ event: BlockStoreEvent, origin: NodeMutationOrigin) {
		guard origin == .localPolicy else { return }
		sendStoreEvent(event)
	}

  /// 외부에서 전달된 스토어 이벤트를 로컬 상태와 동기화합니다.
	@MainActor
  fileprivate func handleExternal(_ event: BlockStoreEvent) async {
    switch event {
    case .inserted(let node, at: let index):
      applyInsertion(node, at: index, origin: .externalStore)

    case .updated(let node, at: let index):
      applyUpdate(node, at: index, origin: .externalStore)

    case .removed(let node, at: let index):
      applyRemoval(node, at: index, origin: .externalStore)

    case .merged(let source, let target):
      applyRemoval(source, at: nil, origin: .externalStore)
      applyUpdate(target, at: nil, origin: .externalStore)

    case .replaced(let newNodes):
      nodes = newNodes
    }
  }

  /// 지정된 위치에 노드를 삽입하고 필요한 알림을 발행합니다.
  fileprivate func applyInsertion(_ node: BlockNode, at index: Int, origin: NodeMutationOrigin) {
    let clamped = max(0, min(index, nodes.count))
    nodes.insert(node, at: clamped)
    enqueueNodeEvent(.insert(node: node, index: clamped))
    publishStoreEvent(.inserted(node, at: clamped), origin: origin)
  }

  /// 노드 내용을 갱신하고 알림을 발행합니다.
  fileprivate func applyUpdate(_ node: BlockNode, at indexHint: Int?, origin: NodeMutationOrigin) {
    let idx = indexHint ?? index(ofNodeID: node.id)
    guard let idx else { return }

    nodes[idx].kind = node.kind
    nodes[idx].text = node.text
    nodes[idx].listNumber = node.listNumber
    enqueueNodeEvent(.update(node: nodes[idx], index: idx))
    publishStoreEvent(.updated(nodes[idx], at: idx), origin: origin)
  }

  /// 노드를 제거하고 삭제 알림을 발행합니다.
  fileprivate func applyRemoval(_ node: BlockNode, at indexHint: Int?, origin: NodeMutationOrigin) {
    let idx = indexHint ?? index(ofNodeID: node.id)
    guard let idx, nodes.indices.contains(idx) else { return }

    let removed = nodes.remove(at: idx)
    enqueueNodeEvent(.remove(node: removed, index: idx))
    publishStoreEvent(.removed(removed, at: idx), origin: origin)
  }
}

// MARK: - BlockEditingContext

extension EditorBlockManager: BlockEditingContext {
  /// 주어진 노드 식별자의 현재 인덱스를 조회합니다.
  func index(of nodeID: UUID) -> Int? {
    index(ofNodeID: nodeID)
  }

  /// 이전 형제 노드를 반환합니다.
  func node(before nodeID: UUID) -> BlockNode? {
    guard let idx = index(ofNodeID: nodeID), idx > 0 else { return nil }
    return nodes[idx - 1]
  }

  /// 다음 형제 노드를 반환합니다.
  func node(after nodeID: UUID) -> BlockNode? {
    guard let idx = index(ofNodeID: nodeID), idx < nodes.count - 1 else { return nil }
    return nodes[idx + 1]
  }

  /// 지정 노드를 분할하고 새 꼬리 노드를 반환합니다.
  func split(nodeID: UUID, atUTF16 offset: Int) -> BlockNode? {
    guard let idx = index(ofNodeID: nodeID) else { return nil }
    let node = nodes[idx]

    let nsText = node.text as NSString
    let length = nsText.length
    let clamped = max(0, min(offset, length))
    let head = nsText.substring(to: clamped)
    let tail = nsText.substring(from: clamped)

    if node.text != head {
      node.text = head
      applyUpdate(node, at: idx, origin: .localPolicy)
    }

    let newNode = BlockNode(kind: node.kind, text: tail)
    applyInsertion(newNode, at: idx + 1, origin: .localPolicy)
    return newNode
  }

  /// 새 노드를 삽입합니다.
  func insert(node: BlockNode, at index: Int) {
    applyInsertion(node, at: index, origin: .localPolicy)
  }

  /// 노드를 제거합니다.
  func remove(nodeID: UUID) {
    guard let idx = index(ofNodeID: nodeID) else { return }
    let node = nodes[idx]
    applyRemoval(node, at: idx, origin: .localPolicy)
  }

  /// 노드 변경 사항을 알립니다.
  func update(node: BlockNode) {
    applyUpdate(node, at: nil, origin: .localPolicy)
  }

  /// 지정 노드를 직전 노드와 병합합니다.
  func merge(nodeID: UUID, into previousID: UUID) {
		guard let sourceIndex = index(ofNodeID: nodeID), sourceIndex > 0 else { return }
		let previousIndex = sourceIndex - 1
		guard nodes.indices.contains(previousIndex), nodes[previousIndex].id == previousID else { return }
		
		let previous = nodes[previousIndex]
		let source = nodes[sourceIndex]
		previous.text += source.text
		
		applyRemoval(source, at: sourceIndex, origin: .localPolicy)
		applyUpdate(previous, at: previousIndex, origin: .localPolicy)
		publishStoreEvent(.merged(source: source, target: previous), origin: .localPolicy)
  }
}

extension EditorBlockManager {
	/// 주어진 식별자를 가진 노드의 인덱스를 반환합니다.
	fileprivate func index(ofNodeID id: UUID) -> Int? {
		nodes.firstIndex(where: { $0.id == id })
	}
	
}
