//
//  SimpleBlockExampleApp.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import SwiftUI

final class BlockStoreImpl: BlockStore {
	func load() async -> [BlockNode] {
		[

		]
	}

	func updates() -> AsyncStream<BlockStoreEvent> {
		AsyncStream { continuation in
			continuation.finish()
		}
	}

	func apply(_ event: BlockStoreEvent) async {
		switch event {
		case .inserted(let node, let at):
			print("Inserted node \(node.id) at \(at)")
		case .updated(let node, let at):
			print("Updated node \(node.id) at \(at)")
		case .removed(let node, let at):
			print("Removed node \(node.id) at \(at)")
		case .merged(let source, let target):
			print("Merged node \(source.id) into \(target.id)")
		case .replaced(let newNodes):
			print("Replaced all nodes with \(newNodes.count) new nodes")
		}
	}
}

@main
struct SimpleBlockExampleApp: App {
	var body: some Scene {
		WindowGroup {
			ContentView(store: BlockStoreImpl())
		}
	}
}
