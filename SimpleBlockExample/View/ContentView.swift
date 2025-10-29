//
//  ContentView.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import SwiftUI

// MARK: - BlockNode & BlockDocuments

@Observable
final class BlockNode: Identifiable, Equatable {
	let id = UUID()
	var kind: BlockKind
	var text: String
	var listNumber: Int? // ordered일 때만 의미
	
	init(kind: BlockKind, text: String = "", listNumber: Int? = nil) {
		self.kind = kind; self.text = text; self.listNumber = listNumber
	}
	
	static func == (l: BlockNode, r: BlockNode) -> Bool { l.id == r.id }
}

@Observable
final class BlockDocuments {
	private(set) var focusedNodeID: UUID? = nil
	
	private(set) var nodes: [BlockNode] = [
		BlockNode(kind: .heading(level: 1), text: "이것은 제목"),
		BlockNode(kind: .todo(checked: false), text: "할 일1"),
	]
	
	func setFocus(to node: BlockNode) {
		focusedNodeID = node.id
	}
	
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
	
	func decide(_ e: EditorEvent, for node: BlockNode) -> EditCommand? {
		switch e {
		case .space(let info):
			if let (match, remove) = matchLeadingTriggerSpace(text: node.text, caretUTF16: info.utf16) {
				// TODO: - 숫자 순서 처리 로직 추가
				applyKindChange(match: match, to: node)
				return EditCommand(removePrefixUTF16: remove, setCaretUTF16: 0)
			}
			return nil
			
		case .enter(let info, let isTail):
			guard let idx = getIndex(of: node) else { return nil }
			
			var kind = BlockKind.paragraph
			if node.kind == .bullet || node.kind == .ordered || node.kind == .todo(checked: false) || node.kind == .todo(checked: true) {
				kind = node.kind
			}
			
			if !isTail {
				let tail = node.text.cutSuffix(fromGrapheme: info.grapheme)
				insertNode(BlockNode(kind: kind, text: tail), at: idx + 1)
			} else {
				insertNode(BlockNode(kind: kind), at: idx + 1)
			}
			
			setFocus(to: nodes[idx + 1])
			
			return nil
			
		case .shiftEnter:
			return nil
			
		case .deleteAtStart:
			if node.kind != .paragraph {
				node.kind = .paragraph
			} else {
				guard let prev = getPreviousNode(of: node) else { return nil }
				if !node.text.isEmpty {
					prev.text += node.text
				}
				if let idx = getIndex(of: node) {
					nodes.remove(at: idx)
					setFocus(to: prev)
				}
			}
			return nil
		}
	}
	
	private func getIndex(of node: BlockNode) -> Int? {
		nodes.firstIndex(of: node)
	}
}
extension BlockDocuments {
	private func applyKindChange(match: TriggerMatch, to node: BlockNode) {
		switch match {
		case .heading(let lv): node.kind = .heading(level: lv)
		case .bullet:          node.kind = .bullet
		case .todo(let c):     node.kind = .todo(checked: c)
		}
	}
}

// MARK: - Content View

struct ContentView: View {
	@State private var doc = BlockDocuments()
	
	var body: some View {
		List {
			ForEach(doc.nodes) { node in
				BlockRowEditor(doc: doc, node: node)
					.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
					.listRowSeparator(.hidden)
			}
		}
		.listStyle(.plain)
		.toolbar {
			Button {
				doc.appendNode(BlockNode(kind: .paragraph))
			} label: {
				Image(systemName: "plus")
			}
		}
	}
}

#Preview {
	ContentView()
		.background(.ultraThinMaterial)
		.frame(width: 300, height: 300)
		.padding()
}
