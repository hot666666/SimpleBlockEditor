//
//  BlockRowEditor.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import SwiftUI

// MARK: - BlockRowEditor

struct BlockRowEditor: View {
	private let layout = BlockEditorLayout.default
	@State private var debouncer = Debouncer()
	@State private var isPending = false

	let manager: BlockManager
	@Bindable var node: BlockNode

	private func decide(_ event: EditorEvent) -> EditCommand? {
		manager.decide(event, for: node)
	}
	
	private func send(_ command: EditCommand) {
		flushPending()
		manager.apply(command)
	}
	
	private func handleTextChange() {
		isPending = true
		Task {
			await debouncer.scheduleOnMain {
				if isPending {
					manager.notifyUpdate(of: node)
					isPending = false
				}
			}
		}
	}
	
	private func flushPending() {
		Task {
			await debouncer.cancel()
			if isPending {
				manager.notifyUpdate(of: node)
				isPending = false
			}
		}
	}
	
	var body: some View {
		HStack(alignment: .top, spacing: layout.gutterSpacing) {
			gutterView()
			AutoGrowTextEditor(
				nodeID: node.id,
				text: $node.text,
				font: node.kind.font,
				textInsets: layout.textInsets,
				onDecide: decide,
				onApply: send
			)
			.fixedSize(horizontal: false, vertical: true)
		}
		.onChange(of: node.text) { _, _ in
			handleTextChange()
		}
		.onDisappear {
			flushPending()
		}
	}
}

// MARK: - Gutters

private extension BlockRowEditor {
	@ViewBuilder
	func gutterView() -> some View {
		switch node.kind {
		case .bullet:
			defaultGutter {
				Circle()
					.fill(Color.secondary)
					.frame(width: 6, height: 6)
			}
			
		case .ordered:
			let numberText = "\(node.listNumber ?? 1)."
			defaultGutter {
				Text(verbatim: numberText)
					.monospacedDigit()
					.font(.system(size: 12))
					.foregroundColor(.secondary)
			}
			
		case .todo(let checked):
			defaultGutter {
				Button {
					node.kind = .todo(checked: !checked)
					flushPending()
					manager.notifyUpdate(of: node)
				} label: {
					Image(systemName: checked ? "checkmark.square.fill" : "square")
						.font(.system(size: 14, weight: .medium))
				}
				.buttonStyle(.plain)
			}
			
		default:
			EmptyView()
		}
	}
	
	@ViewBuilder
	func defaultGutter<Content: View>(@ViewBuilder content: () -> Content) -> some View {
		content()
			.frame(width: layout.gutterSize.width, height: layout.gutterSize.height, alignment: .center)
			.padding(.top, layout.centerPadding(for: node.kind, font: node.kind.font))
	}
}
