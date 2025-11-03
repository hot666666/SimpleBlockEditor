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

	let layout: BlockEditorLayout
	let gutter: BlockGutterProvider

	private var decide: (EditorEvent) -> EditCommand? {
		{ event in doc.decide(event, for: node) }
	}

	private var apply: (EditCommand) -> Void {
		{ command in doc.apply(command) }
	}

	var body: some View {
		HStack(alignment: .top, spacing: layout.gutterSpacing) {
			if let gutterView = gutter(node, $node.kind) {
				gutterView
					.frame(
						width: layout.gutterSize.width,
						height: layout.gutterSize.height
					)
					.padding(.top, layout.topPadding(for: node.kind))
			}

			AutoGrowTextEditor(
				nodeID: node.id,
				text: $node.text,
				font: node.kind.font,
				textInsets: layout.textInsets,
				onDecide: decide,
				onApply: apply
			)
			.fixedSize(horizontal: false, vertical: true)
		}
		.onChange(of: node) { _, newNode in
			doc.notifyUpdate(of: newNode)
		}
	}
}
