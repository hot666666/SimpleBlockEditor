//
//  BlockManager.swift
//  SimpleBlockExample
//
//  Created by hs on 11/1/25.
//

import SwiftUI

@Observable
final class BlockManager {
	private(set) var focusedNodeID: UUID?
	private(set) var nodes: [BlockNode]

	private let policy: any BlockEditingPolicy
	private let storeActions: BlockStoreActions

	init(
		nodes: [BlockNode] = [],
		policy: any BlockEditingPolicy = DefaultBlockEditingPolicy(),
		focusedNodeID: UUID? = nil,
		storeActions: BlockStoreActions = BlockStoreActions()
	) {
		self.nodes = nodes
		self.policy = policy
		self.focusedNodeID = focusedNodeID
		self.storeActions = storeActions
	}

	// MARK: - Public mutations

	func appendNode(_ node: BlockNode) {
		insertNode(node, at: nodes.count)
	}

	func insertNode(_ node: BlockNode, at index: Int) {
		let clampedIndex = max(0, min(index, nodes.count))
		nodes.insert(node, at: clampedIndex)
		storeActions.onInsert?(node, clampedIndex)
	}

	// MARK: - Policy bridge

	func decide(_ event: EditorEvent, for node: BlockNode) -> EditCommand? {
		policy.decide(event: event, node: node, in: self)
	}

	// MARK: - NSTextView에서 SwiftUI가 해야할 명령 적용

	func apply(_ cmd: EditCommand) {
		guard let focusChange = cmd.requestFocusChange else { return }

		switch focusChange {
		case .otherNode(let id, _):
			guard let node = nodes.first(where: { $0.id == id }) else { return }
			focusedNodeID = node.id
		case .clear:
			focusedNodeID = nil
		}
	}

	func notifyUpdate(of node: BlockNode) {
		guard let idx = index(of: node) else { return }
		storeActions.onUpdate?(node, idx)
	}
}

// MARK: - BlockEditingContext

extension BlockManager: BlockEditingContext {
	func index(of node: BlockNode) -> Int? {
		nodes.firstIndex(of: node)
	}

	func previousNode(of node: BlockNode) -> BlockNode? {
		guard let idx = index(of: node), idx > 0 else { return nil }
		return nodes[idx - 1]
	}

	func nextNode(of node: BlockNode) -> BlockNode? {
		guard let idx = index(of: node), idx < nodes.count - 1 else { return nil }
		return nodes[idx + 1]
	}

	func removeNode(at index: Int) {
		guard nodes.indices.contains(index) else { return }
		let removed = nodes.remove(at: index)
		storeActions.onRemove?(removed, index)
	}

	func notifyMerge(from source: BlockNode, into target: BlockNode) {
		storeActions.onMerge?(source, target)
	}
}
