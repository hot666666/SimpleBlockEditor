//
//  BlockManager.swift
//  SimpleBlockExample
//
//  Created by hs on 11/1/25.
//

import SwiftUI

@Observable
final class BlockManager {
	private(set) var focusedNodeID: UUID? = nil
	
	private(set) var nodes: [BlockNode] = [
		BlockNode(kind: .heading(level: 1), text: "이것은 제목"),
		BlockNode(kind: .todo(checked: false), text: "할일1"),
		BlockNode(kind: .todo(checked: false), text: "할일2 ")
	]
	
	func appendNode(_ node: BlockNode) {
		nodes.append(node)
	}
	
	func insertNode(_ node: BlockNode, at index: Int) {
		nodes.insert(node, at: index)
	}
	
	func getPreviousNode(of node: BlockNode) -> BlockNode? {
		guard let idx = getIndex(of: node), idx > 0 else { return nil }
		return nodes[idx - 1]
	}
	
	func getNextNode(of node: BlockNode) -> BlockNode? {
		guard let idx = getIndex(of: node), idx < nodes.count - 1 else { return nil }
		return nodes[idx + 1]
	}
	
	// MARK: - NSTextView에서 수행할 명령 결정
	
	func decide(_ e: EditorEvent, for node: BlockNode) -> EditCommand? {
		switch e {
		case .space(let info):
			guard let (match, remove) = matchLeadingTriggerSpace(text: node.text, caretUTF16: info.utf16) else { return nil }
			// TODO: - 숫자 순서 처리 로직 추가
			switch match {
			case .heading(let lv):
				node.kind = .heading(level: lv)
			case .bullet:
				node.kind = .bullet
			case .todo(let c):
				node.kind = .todo(checked: c)
			}
			return EditCommand(removePrefixUTF16: remove, setCaretUTF16: 0)
			
		case .enter(let info, let isTail):
			guard let idx = getIndex(of: node) else { return nil }
			
			var kind = BlockKind.paragraph
			switch node.kind {
			case .bullet, .ordered, .todo(false):
				kind = node.kind
			case .todo(true):
				kind = .todo(checked: false)
			default:
				kind = .paragraph
			}
			
			if !isTail {
				let tail = node.text.cutSuffix(fromGrapheme: info.grapheme)
				let newNode = BlockNode(kind: kind, text: tail)
				insertNode(newNode, at: idx + 1)
				return EditCommand(requestFocusChange: .otherNode(id: newNode.id, caret: 0))
			} else {
				let newNode = BlockNode(kind: kind)
				insertNode(newNode, at: idx + 1)
				return EditCommand(requestFocusChange: .otherNode(id: newNode.id, caret: 0))
			}
			
		case .deleteAtStart:
			if node.kind != .paragraph {
				node.kind = .paragraph
				return EditCommand(setCaretUTF16: 0)
			} else {
				guard let prev = getPreviousNode(of: node),
						let idx = getIndex(of: node) else { return nil }
				let caret = prev.text.count
				nodes.remove(at: idx)
				prev.text += node.text
				
				return EditCommand(requestFocusChange: .otherNode(id: prev.id, caret: caret), insertText: node.text)
			}
		
		case .arrowUp(let info):
			guard let prev = getPreviousNode(of: node) else { return nil }
			let prevUTF16 = (prev.text as NSString).length
			let newCaret: Int
			if prev.text.contains(where: \.isNewline) {
				newCaret = prevUTF16
			} else {
				newCaret = min(info.columnUTF16, prevUTF16)
			}
			
			return EditCommand(requestFocusChange: .otherNode(id: prev.id, caret: newCaret))
			
		case .arrowDown(let info):
			guard let next = getNextNode(of: node) else { return nil }
			let nextUTF16 = (next.text as NSString).length
			let newCaret = min(info.columnUTF16, nextUTF16)
			
			return EditCommand(requestFocusChange: .otherNode(id: next.id, caret: newCaret))
			
		case .arrowLeft(let info):
			guard info.isAtStart, let prev = getPreviousNode(of: node) else { return nil }
			let prevUTF16 = (prev.text as NSString).length
			return EditCommand(requestFocusChange: .otherNode(id: prev.id, caret: prevUTF16))
			
		case .arrowRight(let info):
			guard info.isAtTail, let next = getNextNode(of: node) else { return nil }
			return EditCommand(requestFocusChange: .otherNode(id: next.id, caret: 0))
			
		case .shiftEnter:
			return nil
		}
	}
	
	// MARK: - NSTextView에서 SwiftUI가 해야할 명령 적용
	
	func apply(_ cmd: EditCommand) {
		guard let fc = cmd.requestFocusChange else { return }
		
		switch fc {
		case .otherNode(let id, _):
			guard let node = nodes.first(where: { $0.id == id }) else { return }
			focusedNodeID = node.id
		case .clear:
			focusedNodeID = nil
		}
	}
	
	private func getIndex(of node: BlockNode) -> Int? {
		nodes.firstIndex(of: node)
	}
}
