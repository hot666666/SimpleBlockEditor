//
//  AutoGrowTextEditor.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import SwiftUI

struct AutoGrowTextEditor: NSViewRepresentable {
	@Binding var text: String
	var font: NSFont
	var textInsets: NSSize = .init(width: 0, height: 0)
	var isFocused: Bool = false
	
	// SwiftUI에서 의사결정 내려주는 훅 (없으면 기본 nil 반환)
	var onDecide: (EditorEvent) -> EditCommand? = { _ in nil }
	
	// Row가 주는 포커스 지시 콜백
	var onClick: () -> Void = {}
	
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
		
		// 결정 콜백 연결
		tv._decide = onDecide
		// 포커스 콜백 연결
		tv._onClick = onClick

		return tv
	}
	
	func updateNSView(_ tv: AutoSizingTextView, context: Context) {
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
		
		// 포커스 토글 (매 프레임 훔치지 않게 비교 후 적용)
		if isFocused {
			if tv.window?.firstResponder !== tv {
				// window 붙기 전에 부르면 실패할 수 있으니 main-async 한 번 감싸는 게 안전
				DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
			}
		} else {
			// 선택영역 해제
			tv.selectedRange = .init(location: 0, length: 0)
			if tv.window?.firstResponder === tv {
				tv.window?.makeFirstResponder(nil) // 포커스 해제
			}
		}
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
