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
	private(set) var nodes: [BlockNode] = [
		BlockNode(kind: .paragraph),
		BlockNode(kind: .todo(checked: false))
	]
	
	func appendNode(_ node: BlockNode) {
		nodes.append(node)
	}
	
	func decide(_ e: EditorEvent, for node: BlockNode) -> EditCommand? {
		switch e {
		case .space(let info):
			if let (m, remove) = matchLeadingTriggerSpace(text: node.text, caretUTF16: info.utf16) {
				applyKindChange(match: m, to: node)
				return EditCommand(removePrefixUTF16: remove, setCaretUTF16: 0)
			}
			return nil
			
		case .enter(let info, let tail):
			// TODO: 분할 로직 (node를 둘로 쪼개 nodes에 삽입)
			_ = (info, tail)
			return nil
			
		case .shiftEnter:
			// TODO: 소프트 브레이크 정책
			return nil
			
		case .deleteAtStart:
			// TODO: 병합/타입 해제 정책
			return nil
		}
	}
	
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
