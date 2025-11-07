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
	var font: NSFont
	var textInsets: NSSize = .init(width: 0, height: 6)

	// SwiftUI에서 의사결정 내려주는 훅 (없으면 기본 nil 반환)
	var onDecide: (EditorEvent) -> EditCommand? = { _ in nil }

	// Row가 주는 포커스 지시 콜백
	var onApply: (EditCommand) -> Void = { _ in }

	func makeNSView(context: Context) -> AutoSizingTextView {
		let tv = AutoSizingTextView()
		tv.isEditable = true
		tv.isRichText = false
		tv.drawsBackground = false
		tv.font = font
		tv.textColor = .labelColor
		tv.textContainerInset = textInsets
		tv.allowsUndo = true
		tv.delegate = context.coordinator
		tv.string = text
		
		tv.nodeID = nodeID
		// 결정 콜백 연결
		tv._decide = onDecide
		// 포커스 콜백 연결
		tv._apply = onApply
		// 레지스트리에 등록
		EditorRegistry.shared.register(nodeID: nodeID, view: tv)
		
		tv.normalizeBaselineIfNeeded()

		return tv
	}

	func updateNSView(_ tv: AutoSizingTextView, context: Context) {
		context.coordinator.parent = self
		tv._decide = onDecide
		tv._apply = onApply
		
		if tv.string != text {
			tv.undoManager?.disableUndoRegistration()
			tv.string = text
			tv.undoManager?.enableUndoRegistration()
			tv.invalidateIntrinsicContentSize()
		}
		if tv.font?.isEqual(font) == false {
			tv.typingAttributes[.font] = font
			tv.textStorage?.beginEditing()
			if let ts = tv.textStorage {
				let full = NSRange(location: 0, length: ts.length)
				ts.removeAttribute(.font, range: full)
				ts.addAttribute(.font, value: font, range: full)
			}
			tv.textStorage?.endEditing()
			tv.font = font
			tv.invalidateIntrinsicContentSize()
		}
		if tv.textContainerInset != textInsets {
			tv.textContainerInset = textInsets
			tv.invalidateIntrinsicContentSize()
		}
		
		tv.normalizeBaselineIfNeeded()
	}

	func makeCoordinator() -> Coordinator { Coordinator(self) }

	final class Coordinator: NSObject, NSTextViewDelegate {
		var parent: AutoGrowTextEditor
		init(_ parent: AutoGrowTextEditor) { self.parent = parent }
		
		func textDidChange(_ notification: Notification) {
			guard let tv = notification.object as? NSTextView else { return }
			parent.text = tv.string
		}
	}
}
