//
//  BlockRowEditor.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import SwiftUI

// MARK: - Block Row Editor

struct BlockRowEditor: View {
	let doc: BlockDocuments
	@Bindable var node: BlockNode
	
	var decide: (EditorEvent) -> EditCommand? {
		{ e in doc.decide(e, for: node) }
	}
	
	var isFocused: Bool {
		doc.focusedNodeID == node.id
	}
	
	var body: some View {
		HStack(alignment: .top, spacing: 3) {
			if node.kind.usesGutter {
				GutterView(
					kind: $node.kind,
					listNumber: node.listNumber
				)
			}
			AutoGrowTextEditor(
				text: $node.text,
				font: node.kind.font,
				isFocused: isFocused,
				onDecide: decide
			)
			.fixedSize(horizontal: false, vertical: true)
		}
	}
}

// MARK: - Gutter View

fileprivate struct GutterView: View {
	@Binding var kind: BlockKind
	var listNumber: Int?
	
	var body: some View {
		content
			.font(Font(kind.font))
	}
	
	@ViewBuilder
	private var content: some View {
		switch kind {
		case .bullet:
			Text("•")
			
		case .ordered:
			Text("\(listNumber ?? 1).")
				.monospacedDigit()
			
		case .todo(let checked):
			Button {
				kind = .todo(checked: !checked)
			} label: {
				Image(systemName: checked ? "checkmark.square.fill" : "square")
			}
			.buttonStyle(.plain)
			
		default:
			EmptyView()
		}
	}
}
