//
//  EditCommand.swift
//  SimpleBlockExample
//
//  Created by hs on 10/29/25.
//

import Foundation

/// SwiftUI → NSTextView로 내려가는 편집 명령
struct EditCommand {
	/// 현재 문자열 맨 앞에서 제거할 UTF16 길이 (예: "# " → 2)
	var removePrefixUTF16: Int? = nil
	
	/// 캐럿 이동 위치 (같은 노드 내부)
	var setCaretUTF16: Int? = nil
	
	/// 다른 노드로 포커스 전환 명령
	var requestFocusChange: FocusChange? = nil
	
	/// 텍스트 자동 삽입 명령
	var insertText: String? = nil
	
	/// 임의의 범위 교체 명령 (보다 세밀한 제어용)
	var replaceRange: (range: NSRange, text: String)? = nil
	
	init(
		removePrefixUTF16: Int? = nil,
		setCaretUTF16: Int? = nil,
		requestFocusChange: FocusChange? = nil,
		insertText: String? = nil,
		replaceRange: (range: NSRange, text: String)? = nil
	) {
		self.removePrefixUTF16 = removePrefixUTF16
		self.setCaretUTF16 = setCaretUTF16
		self.requestFocusChange = requestFocusChange
		self.insertText = insertText
		self.replaceRange = replaceRange
	}
}

/// 포커스 이동 종류
enum FocusChange: Equatable {
    case otherNode(id: UUID, caret: Int)
    case clear
}

// Make equality usable from non-main-actor contexts (e.g., pure model tests).
extension FocusChange {
    nonisolated static func == (lhs: FocusChange, rhs: FocusChange) -> Bool {
        switch (lhs, rhs) {
        case (.clear, .clear):
            return true
        case let (.otherNode(id1, caret1), .otherNode(id2, caret2)):
            return id1 == id2 && caret1 == caret2
        default:
            return false
        }
    }
}
