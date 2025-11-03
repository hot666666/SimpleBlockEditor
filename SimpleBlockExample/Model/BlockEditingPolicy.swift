//
//  BlockEditingPolicy.swift
//  SimpleBlockExample
//
//  Created by hs on 2/5/26.
//

import Foundation

protocol BlockEditingPolicy {
	func decide(event: EditorEvent, node: BlockNode, in context: BlockEditingContext) -> EditCommand?
}

struct DefaultBlockEditingPolicy: BlockEditingPolicy {
	func decide(event: EditorEvent, node: BlockNode, in context: BlockEditingContext) -> EditCommand? {
		switch event {
		case .space(let info):
			return handleSpace(info: info, node: node, context: context)

		case .enter(let info, let isTail):
			return handleEnter(info: info, isTail: isTail, node: node, context: context)

		case .shiftEnter:
			return nil

		case .deleteAtStart:
			return handleDeleteAtStart(node: node, context: context)

		case .arrowUp(let info):
			return handleArrowUp(info: info, node: node, context: context)

		case .arrowDown(let info):
			return handleArrowDown(info: info, node: node, context: context)

		case .arrowLeft(let info):
			return handleArrowLeft(info: info, node: node, context: context)

		case .arrowRight(let info):
			return handleArrowRight(info: info, node: node, context: context)
		}
	}
}

private extension DefaultBlockEditingPolicy {
	func handleSpace(info: CaretInfo, node: BlockNode, context: BlockEditingContext) -> EditCommand? {
		guard let (match, remove) = matchLeadingTriggerSpace(text: node.text, caretUTF16: info.utf16) else {
			return nil
		}

		switch match {
		case .heading(let level):
			node.kind = .heading(level: level)
		case .bullet:
			node.kind = .bullet
		case .todo(let checked):
			node.kind = .todo(checked: checked)
		}
		context.notifyUpdate(of: node)

		return EditCommand(removePrefixUTF16: remove, setCaretUTF16: 0)
	}

	func handleEnter(info: CaretInfo, isTail: Bool, node: BlockNode, context: BlockEditingContext) -> EditCommand? {
		guard let index = context.index(of: node) else { return nil }

		let nextKind: BlockKind
		switch node.kind {
		case .bullet, .ordered, .todo(false):
			nextKind = node.kind
		case .todo(true):
			nextKind = .todo(checked: false)
		default:
			nextKind = .paragraph
		}

		let insertionIndex = index + 1

		if !isTail {
			let tail = node.text.cutSuffix(fromGrapheme: info.grapheme)
			context.notifyUpdate(of: node)

			let newNode = BlockNode(kind: nextKind, text: tail)
			context.insertNode(newNode, at: insertionIndex)

			return EditCommand(requestFocusChange: .otherNode(id: newNode.id, caret: 0))
		} else {
			let newNode = BlockNode(kind: nextKind)
			context.insertNode(newNode, at: insertionIndex)

			return EditCommand(requestFocusChange: .otherNode(id: newNode.id, caret: 0))
		}
	}

	func handleDeleteAtStart(node: BlockNode, context: BlockEditingContext) -> EditCommand? {
		if node.kind != .paragraph {
			node.kind = .paragraph
			context.notifyUpdate(of: node)
			return EditCommand(setCaretUTF16: 0)
		}

		guard let index = context.index(of: node),
					let previous = context.previousNode(of: node) else { return nil }

		let caret = previous.text.count

		context.removeNode(at: index)
		previous.text += node.text
		context.notifyUpdate(of: previous)
		context.notifyMerge(from: node, into: previous)

		return EditCommand(
			requestFocusChange: .otherNode(id: previous.id, caret: caret),
			insertText: node.text
		)
	}

	func handleArrowUp(info: CaretInfo, node: BlockNode, context: BlockEditingContext) -> EditCommand? {
		guard let previous = context.previousNode(of: node) else { return nil }

		let previousUTF16 = (previous.text as NSString).length
		let newCaret: Int
		if previous.text.contains(where: \.isNewline) {
			newCaret = previousUTF16
		} else {
			newCaret = min(info.columnUTF16, previousUTF16)
		}

		return EditCommand(requestFocusChange: .otherNode(id: previous.id, caret: newCaret))
	}

	func handleArrowDown(info: CaretInfo, node: BlockNode, context: BlockEditingContext) -> EditCommand? {
		guard let next = context.nextNode(of: node) else { return nil }

		let nextUTF16 = (next.text as NSString).length
		let newCaret = min(info.columnUTF16, nextUTF16)

		return EditCommand(requestFocusChange: .otherNode(id: next.id, caret: newCaret))
	}

	func handleArrowLeft(info: CaretInfo, node: BlockNode, context: BlockEditingContext) -> EditCommand? {
		guard info.isAtStart, let previous = context.previousNode(of: node) else { return nil }

		let previousUTF16 = (previous.text as NSString).length
		return EditCommand(requestFocusChange: .otherNode(id: previous.id, caret: previousUTF16))
	}

	func handleArrowRight(info: CaretInfo, node: BlockNode, context: BlockEditingContext) -> EditCommand? {
		guard info.isAtTail, let next = context.nextNode(of: node) else { return nil }

		return EditCommand(requestFocusChange: .otherNode(id: next.id, caret: 0))
	}
}
