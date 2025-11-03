import Foundation
import Testing

@testable import SimpleBlockExample

// MARK: - Tests that BlockManager correctly emits store events on modifications.

@MainActor
@Suite("BlockManagerStoreTests")
struct BlockManagerStoreTests {
	@Test("init without store creates default paragraph")
	func initWithoutStoreCreatesDefaultParagraph() {
		let manager = BlockManager(policy: DefaultBlockEditingPolicy())
		#expect(manager.nodes.count == 1)
		let node = manager.nodes[0]
		#expect(node.kind == .paragraph)
		#expect(node.text.isEmpty)
	}

	@Test("appendNode emits store insert")
	func appendNodeEmitsStoreInsert() async {
		let store = SpyBlockStore(load: [])
		let manager = BlockManager(
			store: store,
			policy: DefaultBlockEditingPolicy()
		)

		_ = await store.waitForLoad()
		var iterator = store.eventsIterator()

		guard let snapshot = await awaitNext(&iterator) else {
			Issue.record("Expected initial replaced snapshot")
			return
		}

		guard case let .replaced(snapshotNodes) = snapshot else {
			Issue.record("Expected replaced snapshot event")
			return
		}
		#expect(snapshotNodes.count == 1)
		#expect(snapshotNodes.first?.kind == .paragraph)

		let node = BlockNode(kind: .paragraph, text: "New")
		manager.appendNode(node)

		guard let event = await awaitNext(&iterator) else {
			Issue.record("Expected inserted event")
			return
		}

		guard case let .inserted(recorded, at: index) = event else {
			Issue.record("Expected inserted event")
			return
		}

		#expect(recorded.id == node.id)
		#expect(index == 1)
	}

	@Test("notifyUpdate emits store update at index")
	func notifyUpdateEmitsStoreUpdate() async {
		let node = BlockNode(kind: .paragraph, text: "Draft")
		let store = SpyBlockStore(load: [node])
		let manager = BlockManager(
			store: store,
			policy: DefaultBlockEditingPolicy()
		)

		_ = await store.waitForLoad()
		var iterator = store.eventsIterator()
		node.text = "Updated"
		manager.notifyUpdate(of: node)

		guard let event = await awaitNext(&iterator) else {
			Issue.record("Expected updated event")
			return
		}

		guard case let .updated(recorded, at: index) = event else {
			Issue.record("Expected updated event")
			return
		}

		#expect(recorded.id == node.id)
		#expect(recorded.text == "Updated")
		#expect(index == 0)
	}

	@Test("removeNode emits store removal")
	func removeNodeEmitsStoreRemoval() async {
		let node = BlockNode(kind: .paragraph, text: "Delete me")
		let store = SpyBlockStore(load: [node])
		let manager = BlockManager(
			store: store,
			policy: DefaultBlockEditingPolicy()
		)

		_ = await store.waitForLoad()
		var iterator = store.eventsIterator()
		manager.removeNode(at: 0)

		guard let event = await awaitNext(&iterator) else {
			Issue.record("Expected removed event")
			return
		}

		guard case let .removed(recorded, at: index) = event else {
			Issue.record("Expected removed event")
			return
		}

		#expect(recorded.id == node.id)
		#expect(index == 0)
	}

	@Test("notifyMerge emits store merge")
	func notifyMergeEmitsStoreMerge() async {
		let head = BlockNode(kind: .paragraph, text: "Hello")
		let tail = BlockNode(kind: .paragraph, text: "World")
		let store = SpyBlockStore(load: [head, tail])
		let manager = BlockManager(
			store: store,
			policy: DefaultBlockEditingPolicy()
		)

		_ = await store.waitForLoad()
		var iterator = store.eventsIterator()
		manager.notifyMerge(from: tail, into: head)

		guard let event = await awaitNext(&iterator) else {
			Issue.record("Expected merged event")
			return
		}

		guard case let .merged(source, target) = event else {
			Issue.record("Expected merged event")
			return
		}

		#expect(source.id == tail.id)
		#expect(target.id == head.id)
	}

	@Test("replaceAll emits store replacement")
	func replaceAllEmitsStoreReplacement() async {
		let initial = BlockNode(kind: .paragraph, text: "Old")
		let store = SpyBlockStore(load: [initial])
		let manager = BlockManager(
			store: store,
			policy: DefaultBlockEditingPolicy()
		)

		_ = await store.waitForLoad()
		var iterator = store.eventsIterator()
		let newNodes = [
			BlockNode(kind: .heading(level: 1), text: "New title"),
			BlockNode(kind: .paragraph, text: "Body")
		]
		manager.replaceAll(with: newNodes)

		guard let event = await awaitNext(&iterator) else {
			Issue.record("Expected replaced event")
			return
		}

		guard case let .replaced(replaced) = event else {
			Issue.record("Expected replaced event")
			return
		}

		#expect(replaced.map(\.id) == newNodes.map(\.id))
	}

	@Test("empty store keeps default node and emits update")
	func emptyStoreKeepsDefaultNodeAndEmitsUpdate() async {
		let store = SpyBlockStore(load: [])
		let manager = BlockManager(
			store: store,
			policy: DefaultBlockEditingPolicy()
		)

		_ = await store.waitForLoad()
		#expect(manager.nodes.count == 1)
		let node = manager.nodes[0]
		#expect(node.kind == .paragraph)

		var iterator = store.eventsIterator()

		guard let snapshot = await awaitNext(&iterator) else {
			Issue.record("Expected initial replaced snapshot")
			return
		}
		guard case let .replaced(snapshotNodes) = snapshot else {
			Issue.record("Expected replaced snapshot event")
			return
		}
		#expect(snapshotNodes.count == 1)

		node.text = "Edited"
		manager.notifyUpdate(of: node)

		guard let event = await awaitNext(&iterator) else {
			Issue.record("Expected update for default node")
			return
		}

		guard case let .updated(recorded, at: index) = event else {
			Issue.record("Expected updated event for default node")
			return
		}

		#expect(recorded.id == node.id)
		#expect(recorded.text == "Edited")
		#expect(index == 0)
	}
}

private final class SpyBlockStore: BlockStore {
	private let loadResult: [BlockNode]
	private let updatesStream: AsyncStream<BlockStoreEvent>
	private let eventsStream: AsyncStream<BlockStoreEvent>
	private let eventsContinuation: AsyncStream<BlockStoreEvent>.Continuation
	private let loadSignalStream: AsyncStream<Void>
	private let loadSignalContinuation: AsyncStream<Void>.Continuation

	init(load: [BlockNode]) {
		self.loadResult = load
		self.updatesStream = AsyncStream { continuation in continuation.finish() }
		let pair = AsyncStream.makeStream(of: BlockStoreEvent.self)
		self.eventsStream = pair.stream
		self.eventsContinuation = pair.continuation
		let loadPair = AsyncStream.makeStream(of: Void.self)
		self.loadSignalStream = loadPair.stream
		self.loadSignalContinuation = loadPair.continuation
	}

	func load() async -> [BlockNode] {
		loadSignalContinuation.yield()
		return loadResult
	}

	func updates() -> AsyncStream<BlockStoreEvent> {
		updatesStream
	}

	func apply(_ event: BlockStoreEvent) async {
		eventsContinuation.yield(event)
	}

	func eventsIterator() -> AsyncStream<BlockStoreEvent>.AsyncIterator {
		eventsStream.makeAsyncIterator()
	}

	func waitForLoad(timeout: Duration = .seconds(1)) async -> Bool {
		var iterator = loadSignalStream.makeAsyncIterator()
		return await awaitNext(&iterator, timeout: timeout) != nil
	}
}

private func awaitNext<Value>(
	_ iterator: inout AsyncStream<Value>.AsyncIterator,
	timeout: Duration = .seconds(1)
) async -> Value? {
	var localIterator = iterator
	let eventTask = Task { await localIterator.next() }
	let timeoutTask = Task {
		try? await Task.sleep(for: timeout)
		eventTask.cancel()
	}
	let result = await eventTask.value
	timeoutTask.cancel()
	if !eventTask.isCancelled {
		iterator = localIterator
	}
	return result
}
