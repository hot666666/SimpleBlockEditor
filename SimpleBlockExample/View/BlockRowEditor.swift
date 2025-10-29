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
	
	private var decide: (EditorEvent) -> EditCommand? {
		{ e in doc.decide(e, for: node) }
	}
	
	private var click: () -> Void {
		{ doc.setFocus(to: node) }
	}
	
	private var isFocused: Bool { doc.focusedNodeID == node.id }
	
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
				onDecide: decide,
				onClick: click
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
		ZStack {
			content
		}
		.frame(width: 14, height: 14)
	}
	
	@ViewBuilder
	private var content: some View {
		switch kind {
		case .bullet:
			Image(systemName: "circle.fill")
				.font(.system(size: 6))
			
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
