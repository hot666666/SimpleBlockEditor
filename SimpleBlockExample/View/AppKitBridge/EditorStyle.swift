//
//  EditorStyle.swift
//  SimpleBlockExample
//
//  Created by hs on 11/8/25.
//

import AppKit

struct EditorStyle: Equatable {
	var font: NSFont
	var textColor: NSColor = .labelColor
	var insertionPointColor: NSColor = .white
	var textInsets: NSSize = .init(width: 0, height: 6)
	
	static func == (lhs: EditorStyle, rhs: EditorStyle) -> Bool {
		lhs.font.isEqual(rhs.font)
		&& lhs.textColor == rhs.textColor
		&& lhs.insertionPointColor == rhs.insertionPointColor
		&& lhs.textInsets == rhs.textInsets
	}
	
	func apply(to textView: NSTextView) {
		if textView.font?.isEqual(font) == false {
			textView.typingAttributes[.font] = font
			textView.textStorage?.beginEditing()
			if let storage = textView.textStorage {
				let fullRange = NSRange(location: 0, length: storage.length)
				storage.removeAttribute(.font, range: fullRange)
				storage.addAttribute(.font, value: font, range: fullRange)
			}
			textView.textStorage?.endEditing()
			textView.font = font
		}
		
		if textView.textColor != textColor {
			textView.textColor = textColor
		}
		
		if textView.insertionPointColor != insertionPointColor {
			textView.insertionPointColor = insertionPointColor
		}
		
		if textView.textContainerInset != textInsets {
			textView.textContainerInset = textInsets
		}
	}
}
