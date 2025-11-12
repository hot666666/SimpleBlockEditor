import Foundation
import Testing

@testable import SimpleBlockExample

// MARK: - Tests that BlockManager correctly emits store events on modifications.

@MainActor
@Suite("BlockManagerStoreTests")
struct BlockManagerStoreTests {
  @Test("init without store creates default paragraph")
  func initWithoutStoreCreatesDefaultParagraph() {
    let manager = EditorBlockManager(policy: DefaultBlockEditingPolicy())
    let nodes = snapshotNodes(manager)
    #expect(nodes.count == 1)
    let node = nodes[0]
    #expect(node.kind == .paragraph)
    #expect(node.text.isEmpty)
  }

  @Test("appendNode emits store insert")
  func appendNodeEmitsStoreInsert() async {
    let store = SpyBlockStore(load: [])
    let manager = EditorBlockManager(
      store: store,
      policy: DefaultBlockEditingPolicy()
    )

    _ = await store.waitForLoad()
    var iterator = store.eventsIterator()

    guard let snapshot = await awaitNext(&iterator) else {
      Issue.record("Expected initial replaced snapshot")
      return
    }

    guard case .replaced(let snapshotNodes) = snapshot else {
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

    guard case .inserted(let recorded, at: let index) = event else {
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
    let manager = EditorBlockManager(
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

    guard case .updated(let recorded, at: let index) = event else {
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
    let manager = EditorBlockManager(
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

    guard case .removed(let recorded, at: let index) = event else {
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
    let manager = EditorBlockManager(
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

    guard case .merged(let source, let target) = event else {
      Issue.record("Expected merged event")
      return
    }

    #expect(source.id == tail.id)
    #expect(target.id == head.id)
  }

  @Test("empty store keeps default node and emits update")
  func emptyStoreKeepsDefaultNodeAndEmitsUpdate() async {
    let store = SpyBlockStore(load: [])
    let manager = EditorBlockManager(
      store: store,
      policy: DefaultBlockEditingPolicy()
    )

    _ = await store.waitForLoad()
    let nodes = snapshotNodes(manager)
    #expect(nodes.count == 1)
    let node = nodes[0]
    #expect(node.kind == .paragraph)

    var iterator = store.eventsIterator()

    guard let snapshot = await awaitNext(&iterator) else {
      Issue.record("Expected initial replaced snapshot")
      return
    }
    guard case .replaced(let snapshotNodes) = snapshot else {
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

    guard case .updated(let recorded, at: let index) = event else {
      Issue.record("Expected updated event for default node")
      return
    }

    #expect(recorded.id == node.id)
    #expect(recorded.text == "Edited")
    #expect(index == 0)
  }
}

// MARK: - Helpers

private func snapshotNodes(_ manager: EditorBlockManager) -> [BlockNode] {
  var result: [BlockNode] = []
  manager.forEachInitialNode { _, node in
    result.append(node)
  }
  return result
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
