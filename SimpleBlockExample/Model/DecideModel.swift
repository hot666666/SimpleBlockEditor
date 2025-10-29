//
//  DecideModel.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

/// 입력 직전/직후 커서 정보 (utf16은 Cocoa 기준, grapheme은 Swift String 기준)
struct CaretInfo {
	let utf16: Int
	let grapheme: Int
}

/// 에디터에서 SwiftUI로 올리는 이벤트 (필요 최소)
enum EditorEvent {
	case space(CaretInfo)                         // 스페이스 눌렀다
	case enter(CaretInfo, Bool)           // 엔터 (isTail: 커서가 줄 끝에 있나)
	case shiftEnter(CaretInfo)                    // 쉬프트+엔터 (소프트 브레이크)
	case deleteAtStart              // 커서가 0에서 delete
}

/// NSTextView에게 내려보낼 편집 명령 (동기 적용)
struct EditCommand {
	var removePrefixUTF16: Int?   // 앞에서 지울 길이 (UTF-16)
	var setCaretUTF16: Int?       // 지운 뒤 커서 위치 (UTF-16)
}
