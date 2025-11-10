//
//  BlockStore.swift
//  SimpleBlockExample
//
//  Created by hs on 11/3/25.
//

import Foundation

protocol BlockStore: AnyObject {
	func load() async -> [BlockNode]
	func updates() -> AsyncStream<BlockStoreEvent>
	func apply(_ event: BlockStoreEvent) async
}

enum BlockStoreEvent: Equatable {
	case inserted(BlockNode, at: Int)
	case updated(BlockNode, at: Int)
	case removed(BlockNode, at: Int)
	case merged(source: BlockNode, target: BlockNode)
	case replaced([BlockNode])
}

// MARK: - In-Memory Block Store

final class InMemoryBlockStore: BlockStore {
	private let loadHandler: () async -> [BlockNode]
	private let updatesHandler: () -> AsyncStream<BlockStoreEvent>
	private let applyHandler: (BlockStoreEvent) async -> Void

	init(
		load: @escaping () async -> [BlockNode] = { [] },
		updates: @escaping () -> AsyncStream<BlockStoreEvent> = {
			AsyncStream { continuation in continuation.finish() }
		},
		apply: @escaping (BlockStoreEvent) async -> Void = { _ in }
	) {
		self.loadHandler = load
		self.updatesHandler = updates
		self.applyHandler = apply
	}

	func load() async -> [BlockNode] {
		await loadHandler()
	}

	func updates() -> AsyncStream<BlockStoreEvent> {
		updatesHandler()
	}

	func apply(_ event: BlockStoreEvent) async {
		await applyHandler(event)
	}
}
