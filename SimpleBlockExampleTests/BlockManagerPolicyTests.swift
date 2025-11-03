import Foundation
import Testing

@testable import SimpleBlockExample

// MARK: - Tests for BlockManager editing policy decisions.

@MainActor
@Suite("BlockManagerPolicyTests")
struct BlockManagerPolicyTests {
	@Test("Space trigger converts heading and removes prefix")
	func spaceTriggerConvertsHeadingAndRemovesPrefix() {
		let node = BlockNode(kind: .paragraph, text: "#")
		let manager = makeManager(nodes: [node])

		let info = singleLineCaret(location: 1, string: "#")

		guard let command = manager.decide(.space(info), for: node) else {
			Issue.record("Expected EditCommand for heading trigger")
			return
		}

		#expect(node.kind == .heading(level: 1))
		#expect(command.removePrefixUTF16 == 2)
		#expect(command.setCaretUTF16 == 0)
	}

	@Test("Space trigger converts todo state")
	func spaceTriggerConvertsTodoState() {
		let node = BlockNode(kind: .paragraph, text: "[x]")
		let manager = makeManager(nodes: [node])

		let info = singleLineCaret(location: 3, string: "[x]")

		guard let command = manager.decide(.space(info), for: node) else {
			Issue.record("Expected EditCommand for todo trigger")
			return
		}

		#expect(node.kind == .todo(checked: true))
		#expect(command.removePrefixUTF16 == 4)
		#expect(command.setCaretUTF16 == 0)
	}

	@Test("Enter at tail inserts sibling and focuses it")
	func enterAtTailInsertsSiblingAndFocusesIt() {
		let node = BlockNode(kind: .todo(checked: false), text: "Task")
		let manager = makeManager(nodes: [node])

		let info = singleLineCaret(location: 4, string: "Task")

		guard let command = manager.decide(.enter(info, true), for: node) else {
			Issue.record("Expected EditCommand for enter at tail")
			return
		}

		#expect(manager.nodes.count == 2)
		let newNode = manager.nodes[1]
		#expect(newNode.kind == .todo(checked: false))
		#expect(newNode.text.isEmpty)
		#expect(command.requestFocusChange == .otherNode(id: newNode.id, caret: 0))
	}

	@Test("Enter inside splits node and keeps tail text")
	func enterInsideSplitsNodeAndKeepsTailText() {
		let node = BlockNode(kind: .paragraph, text: "HelloWorld")
		let manager = makeManager(nodes: [node])

		let info = singleLineCaret(location: 5, string: "HelloWorld")

		guard let command = manager.decide(.enter(info, false), for: node) else {
			Issue.record("Expected EditCommand for enter in middle")
			return
		}

		#expect(manager.nodes.count == 2)
		#expect(node.text == "Hello")

		let newNode = manager.nodes[1]
		#expect(newNode.kind == .paragraph)
		#expect(newNode.text == "World")
		#expect(command.requestFocusChange == .otherNode(id: newNode.id, caret: 0))
	}

	@Test("Delete at start resets style to paragraph")
	func deleteAtStartResetsStyleToParagraph() {
		let node = BlockNode(kind: .heading(level: 2), text: "Title")
		let manager = makeManager(nodes: [node])

		guard let command = manager.decide(.deleteAtStart, for: node) else {
			Issue.record("Expected EditCommand for style reset")
			return
		}

		#expect(node.kind == .paragraph)
		#expect(command.setCaretUTF16 == 0)
	}

	@Test("Delete at start merges with previous paragraph")
	func deleteAtStartMergesWithPreviousParagraph() {
		let prev = BlockNode(kind: .paragraph, text: "Hello")
		let node = BlockNode(kind: .paragraph, text: "World")
		let manager = makeManager(nodes: [prev, node])

		guard let command = manager.decide(.deleteAtStart, for: node) else {
			Issue.record("Expected EditCommand for merge")
			return
		}

		#expect(manager.nodes.count == 1)
		#expect(prev.text == "HelloWorld")
		#expect(command.requestFocusChange == .otherNode(id: prev.id, caret: 5))
		#expect(command.insertText == "World")
	}

	@Test("Arrow left at start focuses previous node end")
	func arrowLeftAtStartFocusesPreviousNodeEnd() {
		let prev = BlockNode(kind: .paragraph, text: "Prev")
		let node = BlockNode(kind: .paragraph, text: "Current")
		let manager = makeManager(nodes: [prev, node])

		let info = singleLineCaret(location: 0, string: "Current")

		guard let command = manager.decide(.arrowLeft(info), for: node) else {
			Issue.record("Expected EditCommand for arrow left")
			return
		}

		#expect(command.requestFocusChange == .otherNode(id: prev.id, caret: 4))
	}

	@Test("Arrow right at tail focuses next node")
	func arrowRightAtTailFocusesNextNode() {
		let node = BlockNode(kind: .paragraph, text: "Current")
		let next = BlockNode(kind: .paragraph, text: "Next")
		let manager = makeManager(nodes: [node, next])

		let info = singleLineCaret(location: 7, string: "Current")

		guard let command = manager.decide(.arrowRight(info), for: node) else {
			Issue.record("Expected EditCommand for arrow right")
			return
		}

		#expect(command.requestFocusChange == .otherNode(id: next.id, caret: 0))
	}

	@Test("Arrow up jumps to previous multi-line node tail")
	func arrowUpJumpsToPreviousMultilineNodeTail() {
		let prev = BlockNode(kind: .paragraph, text: "Hello\nWorld")
		let node = BlockNode(kind: .paragraph, text: "Current")
		let manager = makeManager(nodes: [prev, node])

		let info = singleLineCaret(location: 3, string: "Current")

		guard let command = manager.decide(.arrowUp(info), for: node) else {
			Issue.record("Expected EditCommand for arrow up")
			return
		}

		let expectedCaret = (prev.text as NSString).length
		#expect(command.requestFocusChange == .otherNode(id: prev.id, caret: expectedCaret))
	}

	@Test("Arrow down keeps horizontal column when possible")
	func arrowDownKeepsHorizontalColumnWhenPossible() {
		let node = BlockNode(kind: .paragraph, text: "Current")
		let next = BlockNode(kind: .paragraph, text: "Ok")
		let manager = makeManager(nodes: [node, next])

		let info = singleLineCaret(location: 3, string: "Current")

		guard let command = manager.decide(.arrowDown(info), for: node) else {
			Issue.record("Expected EditCommand for arrow down")
			return
		}

		let expectedCaret = min(info.columnUTF16, (next.text as NSString).length)
		#expect(command.requestFocusChange == .otherNode(id: next.id, caret: expectedCaret))
	}

	@Test("Policy notifies context when style changes")
	func policyNotifiesContextWhenStyleChanges() {
		let node = BlockNode(kind: .paragraph, text: "#")
		let context = MockContext(nodes: [node])
		let policy = DefaultBlockEditingPolicy()

		let info = singleLineCaret(location: 1, string: "#")
		guard let command = policy.decide(event: .space(info), node: node, in: context) else {
			Issue.record("Expected EditCommand for heading trigger")
			return
		}

		#expect(command.removePrefixUTF16 == 2)
		#expect(context.notifiedUpdates.contains { $0 === node })
	}

	@Test("Policy inserts new node via context when splitting")
	func policyInsertsNewNodeViaContextWhenSplitting() {
		let node = BlockNode(kind: .paragraph, text: "HelloWorld")
		let context = MockContext(nodes: [node])
		let policy = DefaultBlockEditingPolicy()

		let info = singleLineCaret(location: 5, string: "HelloWorld")
		guard policy.decide(event: .enter(info, false), node: node, in: context) != nil else {
			Issue.record("Expected EditCommand for enter split")
			return
		}

		#expect(context.insertedNodes.count == 1)
		let inserted = context.insertedNodes[0]
		#expect(inserted.index == 1)
		#expect(inserted.node.kind == .paragraph)
		#expect(inserted.node.text == "World")
		#expect(context.notifiedUpdates.contains { $0 === node })
	}

	@Test("Policy removes and merges nodes through context on delete")
	func policyRemovesAndMergesNodesThroughContextOnDelete() {
		let head = BlockNode(kind: .paragraph, text: "Hello")
		let tail = BlockNode(kind: .paragraph, text: "World")
		let context = MockContext(nodes: [head, tail])
		let policy = DefaultBlockEditingPolicy()

		guard policy.decide(event: .deleteAtStart, node: tail, in: context) != nil else {
			Issue.record("Expected EditCommand for delete at start")
			return
		}

		#expect(context.removedIndices == [1])
		#expect(context.notifiedUpdates.contains { $0 === head })
		let mergePairs = context.notifiedMerges.map { ($0.source, $0.target) }
		#expect(mergePairs.contains { $0.0 === tail && $0.1 === head })
		#expect(head.text == "HelloWorld")
	}
}

// MARK: - Helpers

private final class MockContext: BlockEditingContext {
	var nodes: [BlockNode]
	var insertedNodes: [(node: BlockNode, index: Int)] = []
	var removedIndices: [Int] = []
	var notifiedUpdates: [BlockNode] = []
	var notifiedMerges: [(source: BlockNode, target: BlockNode)] = []

	init(nodes: [BlockNode]) {
		self.nodes = nodes
	}

	func index(of node: BlockNode) -> Int? {
		nodes.firstIndex { $0 === node }
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
		let clamped = max(0, min(index, nodes.count))
		nodes.insert(node, at: clamped)
		insertedNodes.append((node, clamped))
	}

	func removeNode(at index: Int) {
		guard nodes.indices.contains(index) else { return }
		nodes.remove(at: index)
		removedIndices.append(index)
	}

	func notifyUpdate(of node: BlockNode) {
		notifiedUpdates.append(node)
	}

	func notifyMerge(from source: BlockNode, into target: BlockNode) {
		notifiedMerges.append((source, target))
	}
}

private func singleLineCaret(location: Int, string: String, selectionLength: Int = 0) -> CaretInfo {
	let length = (string as NSString).length
	let selection = NSRange(location: location, length: selectionLength)
	return CaretInfo(
		selection: selection,
		utf16: location,
		grapheme: location,
		stringLength: string.count,
		utf16Length: length,
		currentLineIndex: 0,
		totalLineCount: 1,
		lineRangeUTF16: NSRange(location: 0, length: length),
		columnUTF16: location,
		columnGrapheme: location
	)
}

@MainActor
private func makeManager(nodes: [BlockNode]) -> BlockManager {
	let manager = BlockManager(policy: DefaultBlockEditingPolicy())
	manager.replaceAll(with: nodes)
	return manager
}
