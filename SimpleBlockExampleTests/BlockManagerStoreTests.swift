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

  @Test("insert emits store insert")
  func insertEmitsStoreInsert() async {
    let store = SpyBlockStore(load: [])
    let manager = EditorBlockManager(
      store: store,
      policy: DefaultBlockEditingPolicy()
    )

    await startStoreLifecycle(manager: manager, store: store)
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
    append(node: node, to: manager)

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

  @Test("update emits store update at index")
  func updateEmitsStoreUpdate() async {
    let node = BlockNode(kind: .paragraph, text: "Draft")
    let store = SpyBlockStore(load: [node])
    let manager = EditorBlockManager(
      store: store,
      policy: DefaultBlockEditingPolicy()
    )

    await startStoreLifecycle(manager: manager, store: store)
    var iterator = store.eventsIterator()
    node.text = "Updated"
    manager.update(node: node)

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

  @Test("remove emits store removal")
  func removeEmitsStoreRemoval() async {
    let node = BlockNode(kind: .paragraph, text: "Delete me")
    let store = SpyBlockStore(load: [node])
    let manager = EditorBlockManager(
      store: store,
      policy: DefaultBlockEditingPolicy()
    )

    await startStoreLifecycle(manager: manager, store: store)
    var iterator = store.eventsIterator()
    manager.remove(nodeID: node.id)

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

  @Test("merge emits store merge")
  func mergeEmitsStoreMerge() async {
    let head = BlockNode(kind: .paragraph, text: "Hello")
    let tail = BlockNode(kind: .paragraph, text: "World")
    let store = SpyBlockStore(load: [head, tail])
    let manager = EditorBlockManager(
      store: store,
      policy: DefaultBlockEditingPolicy()
    )

    await startStoreLifecycle(manager: manager, store: store)
    var iterator = store.eventsIterator()
    manager.merge(nodeID: tail.id, into: head.id)

    var mergedEvent: BlockStoreEvent?
    for _ in 0..<3 {
      guard let next = await awaitNext(&iterator) else {
        Issue.record("Expected merged event")
        return
      }
      if case .merged = next {
        mergedEvent = next
        break
      }
    }

    guard case .merged(let source, let target) = mergedEvent else {
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

    await startStoreLifecycle(manager: manager, store: store)
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
    manager.update(node: node)

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

private func append(node: BlockNode, to manager: EditorBlockManager) {
  var count = 0
  manager.forEachInitialNode { index, _ in
    count = max(count, index + 1)
  }
  manager.insert(node: node, at: count)
}

@MainActor
private func startStoreLifecycle(manager: EditorBlockManager, store: SpyBlockStore) async {
  let startTask = Task { @MainActor in
    await manager.startStoreSync()
  }
  _ = await store.waitForLoad()
  await startTask.value
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
