//
//  BlockManager.swift
//  SimpleBlockExample
//
//  Created by hs on 11/1/25.
//

import Observation
import Foundation

@Observable
final class BlockManager {
	/// Edit policy & Store
	@ObservationIgnored private let policy: any BlockEditingPolicy
	@ObservationIgnored private let store: BlockStore?
	/// Event clocks
	private var nodeEventClock: UInt64 = 0
	
	@ObservationIgnored private var bootstrapTask: Task<Void, Never>?
	@ObservationIgnored private var nodes: [BlockNode] = [.init(kind: .paragraph, text: "")]
	@ObservationIgnored private var focusedNodeID: UUID?
	@ObservationIgnored private var pendingNodeEvents: [BlockNodeEvent] = []
	
	init(
		store: BlockStore? = nil,
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
	
	// MARK: - Public operations
	
	func forEachInitialNode(_ body: (Int, BlockNode) -> Void) {
		nodes.enumerated().forEach(body)
	}
	
	func editCommand(for event: EditorEvent, node: BlockNode) -> EditCommand? {
		policy.makeEditCommand(for: event, node: node, in: self)
	}
	
	func applyFocusChange(from command: EditCommand) {
		guard let focus = command.requestFocusChange else { return }
		applyFocusChange(focus)
	}
	
	func applyFocusChange(_ focus: FocusChange) {
		switch focus {
		case .otherNode(let id, _):
			focusedNodeID = id
		case .clear:
			focusedNodeID = nil
		}
		enqueueFocusEvent(focus)
	}
	
	func appendNode(_ node: BlockNode) {
		insert(node, at: nodes.count, emitStoreEvent: true)
	}
	
	func observeNodeEvents() -> [BlockNodeEvent] {
		/// withObservationTracking 클로저 내에서 access를 호출하여, nodeEventClock에 대한 의존성을 기록
		access(keyPath: \.nodeEventClock)
		if pendingNodeEvents.isEmpty { return [] }
		let events = pendingNodeEvents
		pendingNodeEvents.removeAll()
		return events
	}
}

private extension BlockManager {
	func enqueueNodeEvent(_ event: BlockNodeEvent) {
		pendingNodeEvents.append(event)
		withMutation(keyPath: \.nodeEventClock) {
			/// 숫자가 최댓값을 넘어가면 다시 0부터 시작
			nodeEventClock &+= 1
		}
	}
	
	func enqueueFocusEvent(_ change: FocusChange) {
		enqueueNodeEvent(.focus(change))
	}
}

// MARK: - Store bootstrap

private extension BlockManager {
	func bootstrapStore() async {
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
	
	// Store에 이벤트 전송
	func sendStoreEvent(_ event: BlockStoreEvent) {
		guard let store else { return }
		Task {
			await store.apply(event)
		}
	}
	
	func handleExternal(_ event: BlockStoreEvent) {
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
	
	func insert(_ node: BlockNode, at index: Int, emitStoreEvent: Bool) {
		let clamped = max(0, min(index, nodes.count))
		nodes.insert(node, at: clamped)
		enqueueNodeEvent(.insert(node: node, index: clamped))
		
		if emitStoreEvent {
			sendStoreEvent(.inserted(node, at: clamped))
		}
	}
	
	func update(_ node: BlockNode, at indexHint: Int?, emitStoreEvent: Bool) {
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
	
	func remove(_ node: BlockNode, at indexHint: Int?, emitStoreEvent: Bool) {
		let idx = indexHint ?? index(ofNodeID: node.id)
		guard let idx else { return }
		
		let removed = nodes.remove(at: idx)
		enqueueNodeEvent(.remove(node: removed, index: idx))
		if emitStoreEvent {
			sendStoreEvent(.removed(removed, at: idx))
		}
	}
	
	func index(ofNodeID id: UUID) -> Int? {
		nodes.firstIndex(where: { $0.id == id })
	}
	
	func sendUpdate(forNodeID nodeID: UUID) {
		guard let idx = index(ofNodeID: nodeID) else { return }
		let node = nodes[idx]
		enqueueNodeEvent(.update(node: node, index: idx))
		sendStoreEvent(.updated(node, at: idx))
	}
}

// MARK: - BlockEditingContext

extension BlockManager: BlockEditingContext {
	func index(of node: BlockNode) -> Int? {
		index(ofNodeID: node.id)
	}
	
	func previousNode(of node: BlockNode) -> BlockNode? {
		guard let idx = index(of: node), idx > 0 else { return nil }
		return nodes[idx - 1]
	}
	
	func nextNode(of node: BlockNode) -> BlockNode? {
		guard let idx = index(of: node), idx < nodes.count - 1 else { return nil }
		return nodes[idx + 1]
	}
	
	func insertNode(_ node: BlockNode, at index: Int) {
		insert(node, at: index, emitStoreEvent: true)
	}
	
	func removeNode(at index: Int) {
		guard nodes.indices.contains(index) else { return }
		let node = nodes[index]
		remove(node, at: index, emitStoreEvent: true)
	}
	
	func notifyUpdate(of node: BlockNode) {
		guard let idx = index(of: node) else { return }
		enqueueNodeEvent(.update(node: nodes[idx], index: idx))
		sendStoreEvent(.updated(nodes[idx], at: idx))
	}
	
	func notifyMerge(from source: BlockNode, into target: BlockNode) {
		sendStoreEvent(.merged(source: source, target: target))
	}
}
