//
//  BlockManager.swift
//  SimpleBlockExample
//
//  Created by hs on 11/1/25.
//

import SwiftUI

@Observable
final class BlockManager: @unchecked Sendable {
	private let policy: any BlockEditingPolicy
	private let store: BlockStore?
	
	private(set) var nodes: [BlockNode] = [.init(kind: .paragraph, text: "")]
	private(set) var focusedNodeID: UUID?
	
	private var listen: Task<Void, Never>?
	
	init(
		store: BlockStore? = nil,
		policy: any BlockEditingPolicy = DefaultBlockEditingPolicy()
	) {
		self.policy = policy
		self.store = store
		
		listen = Task {
			await bootstrapStore()
		}
	}
	
	deinit {
		listen?.cancel()
		listen = nil
	}
	
	// MARK: - Public operations
	
	func decide(_ event: EditorEvent, for node: BlockNode) -> EditCommand? {
		policy.decide(event: event, node: node, in: self)
	}
	
	func apply(_ command: EditCommand) {
		guard let focus = command.requestFocusChange else { return }
		switch focus {
		case .otherNode(let id, _):
			focusedNodeID = id
		case .clear:
			focusedNodeID = nil
		}
	}
	
	func appendNode(_ node: BlockNode) {
		insert(node, at: nodes.count, emitStoreEvent: true)
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
		
		if emitStoreEvent {
			sendStoreEvent(.updated(nodes[idx], at: idx))
		}
	}
	
	func remove(_ node: BlockNode, at indexHint: Int?, emitStoreEvent: Bool) {
		let idx = indexHint ?? index(ofNodeID: node.id)
		guard let idx else { return }
		
		let removed = nodes.remove(at: idx)
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
		sendStoreEvent(.updated(nodes[idx], at: idx))
	}
	
	func notifyMerge(from source: BlockNode, into target: BlockNode) {
		sendStoreEvent(.merged(source: source, target: target))
	}
}
