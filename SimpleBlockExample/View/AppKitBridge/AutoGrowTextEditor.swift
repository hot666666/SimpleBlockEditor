//
//  AutoGrowTextEditor.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import SwiftUI

struct AutoGrowTextEditor: NSViewRepresentable {
	let nodeID: UUID
	@Binding var text: String
	var style: EditorStyle

	// SwiftUI에서 의사결정 내려주는 훅 (없으면 기본 nil 반환)
	var onDecide: (EditorEvent) -> EditCommand? = { _ in nil }

	// Row가 주는 포커스 지시 콜백
	var onApply: (EditCommand) -> Void = { _ in }

	func makeNSView(context: Context) -> AutoSizingTextView {
		let tv = AutoSizingTextView()
		tv.isEditable = true
		tv.isRichText = false
		tv.drawsBackground = false
		tv.allowsUndo = true
		tv.delegate = context.coordinator
		tv.string = text
		style.apply(to: tv)
		tv.interactionDelegate = context.coordinator
		
		context.coordinator.nodeID = nodeID
		
		return tv
	}

	func updateNSView(_ tv: AutoSizingTextView, context: Context) {
		context.coordinator.parent = self
		context.coordinator.nodeID = nodeID
		tv.interactionDelegate = context.coordinator
		
		if tv.string != text {
			tv.withUndoGroup {
				tv.string = text
			}
		}
		style.apply(to: tv)
		
		tv.invalidateIntrinsicContentSize()
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(nodeID: nodeID, parent: self)
	}

	final class Coordinator: NSObject, NSTextViewDelegate, TextEditorInteractionDelegate {
		var nodeID: UUID
		var parent: AutoGrowTextEditor
		
		init(nodeID: UUID, parent: AutoGrowTextEditor) {
			self.nodeID = nodeID
			self.parent = parent
		}
		
		func textDidChange(_ notification: Notification) {
			guard let tv = notification.object as? NSTextView else { return }
			parent.text = tv.string
		}
		
		func textEditor(_ textView: AutoSizingTextView, decide event: EditorEvent) -> EditCommand? {
			parent.onDecide(event)
		}
		
		func textEditor(_ textView: AutoSizingTextView, didRequestFocusChange change: FocusChange) {
			parent.onApply(EditCommand(requestFocusChange: change))

			switch change {
			case .otherNode(let id, let caret):
				DispatchQueue.main.async {
					EditorRegistry.shared.makeFirstResponder(nodeID: id, caret: caret)
				}
			case .clear:
				break
			}
		}
		
		func textEditor(_ textView: AutoSizingTextView, willMoveToWindow newWindow: NSWindow?) {
			if newWindow == nil {
				EditorRegistry.shared.unregister(nodeID: nodeID)
			} else {
				EditorRegistry.shared.register(nodeID: nodeID, view: textView)
			}
		}
	}
}
