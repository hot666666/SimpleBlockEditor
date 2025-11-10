//
//  EditorEvent.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

enum EditorEvent {
	case space(CaretInfo)
	case enter(CaretInfo, Bool)   /// Enter(caret: isTail: 커서가 줄 끝)
	case shiftEnter(CaretInfo)
	case deleteAtStart  					/// caret 0에서 delete
	case arrowUp(CaretInfo)
	case arrowDown(CaretInfo)
	case arrowLeft(CaretInfo)
	case arrowRight(CaretInfo)
}
