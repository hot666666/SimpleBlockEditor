import Testing

@testable import SimpleBlockExample

@MainActor
@Suite("BlockManagerObservationTests")
struct BlockManagerObservationTests {
	@Test("insert and update emit node events")
	func insertAndUpdateEmitNodeEvents() {
		let manager = BlockManager(policy: DefaultBlockEditingPolicy())
		let fresh = BlockNode(kind: .paragraph, text: "Second line")
		manager.appendNode(fresh)

		let insertEvents = manager.observeNodeEvents()
		guard let insert = insertEvents.last else {
			Issue.record("Expected at least one node event after append")
			return
		}

		switch insert {
		case .insert(let node, let index):
			#expect(node.id == fresh.id)
			#expect(index == 1)
		default:
			Issue.record("Expected insert event, got \(insert)")
		}

		#expect(manager.observeNodeEvents().isEmpty)

		fresh.text = "Edited"
		manager.notifyUpdate(of: fresh)

		let updateEvents = manager.observeNodeEvents()
		guard let update = updateEvents.last else {
			Issue.record("Expected update node event after notifyUpdate")
			return
		}

		switch update {
		case .update(let node, let index):
			#expect(node.id == fresh.id)
			#expect(node.text == "Edited")
			#expect(index == 1)
		default:
			Issue.record("Expected update event, got \(update)")
		}
	}

	@Test("focus changes surface via node events")
	func focusEventsAreReported() {
		let manager = BlockManager(policy: DefaultBlockEditingPolicy())
		var initialNode: BlockNode?
		manager.forEachInitialNode { index, node in
			if index == 0 {
				initialNode = node
			}
		}
		guard let node = initialNode else {
			Issue.record("Expected at least one initial node")
			return
		}

		manager.applyFocusChange(from: EditCommand(requestFocusChange: .otherNode(id: node.id, caret: 2)))

		let nodeEvents = manager.observeNodeEvents()
		guard let last = nodeEvents.last else {
			Issue.record("Expected focus node event")
			return
		}

		switch last {
		case .focus(let change):
			#expect(change == .otherNode(id: node.id, caret: 2))
		default:
			Issue.record("Expected focus node event, got \(last)")
		}
	}
}
