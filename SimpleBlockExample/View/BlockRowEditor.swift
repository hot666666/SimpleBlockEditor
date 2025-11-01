//
//  BlockRowEditor.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import SwiftUI

// MARK: - BlockRowEditor

struct BlockRowEditor: View {
	let doc: BlockManager
	@Bindable var node: BlockNode
	
	private var decide: (EditorEvent) -> EditCommand? {
		{ e in doc.decide(e, for: node) }
	}
	
	private var apply: (EditCommand) -> Void {
		{ cmd in doc.apply(cmd) }
	}
	
	var body: some View {
		HStack(alignment: .top, spacing: BlockRowEditorLayout.gutterSpacing) {
			if node.kind.usesGutter {
				GutterView(
					kind: $node.kind,
					listNumber: node.listNumber
				)
				.frame(width: BlockRowEditorLayout.gutterSize.width, height: BlockRowEditorLayout.gutterSize.height)
				.padding(.top, BlockRowEditorLayout.topPadding(for: node.kind))
			}
			AutoGrowTextEditor(
				nodeID: node.id,
				text: $node.text,
				font: node.kind.font,
				textInsets: BlockRowEditorLayout.textInsets,
				onDecide: decide,
				onApply: apply
			)
			.fixedSize(horizontal: false, vertical: true)
		}
	}
}

// MARK: - GutterView

fileprivate struct GutterView: View {
	@Binding var kind: BlockKind
	var listNumber: Int?
	
	var body: some View {
		content
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
				.font(.system(size: 12))
			
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

// MARK: - BlockRowEditorLayout

fileprivate enum BlockRowEditorLayout {
	static let gutterSize: CGSize = .init(width: 18, height: 18)
	static let gutterSpacing: CGFloat = 4
	static let textInsets: NSSize = .init(width: 0, height: 2)
	static let markerTopOffset: CGFloat = 2
	
	static func topPadding(for kind: BlockKind) -> CGFloat {
		switch kind {
		case .bullet, .ordered, .todo:
			return markerTopOffset
		default:
			return 0
		}
	}
}
