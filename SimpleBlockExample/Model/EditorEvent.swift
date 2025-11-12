//
//  EditorKeyEvent.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import Foundation

// MARK: - EditorBlockEvent

enum EditorBlockEvent: Equatable {
  case insert(node: BlockNode, index: Int)
  case update(node: BlockNode, index: Int)
  case remove(node: BlockNode, index: Int)
  case move(node: BlockNode, from: Int, to: Int)
  case focus(EditorFocusEvent)
}

// MARK: - EditorKeyEvent

/// 한 블록에서 발생하는 주요 키보드 입력을 캡처.
/// 각 케이스는 편집 정책이 판단할 때 필요한 커서 상태와 특정 키(또는 키 조합)
enum EditorKeyEvent {
  case spaceKey(info: BlockCaretInfo)
  case returnKey(info: BlockCaretInfo, isAtTail: Bool)
  case shiftReturnKey(info: BlockCaretInfo)
  case backspaceAtStart
  case arrowUpKey(info: BlockCaretInfo)
  case arrowDownKey(info: BlockCaretInfo)
  case arrowLeftKey(info: BlockCaretInfo)
  case arrowRightKey(info: BlockCaretInfo)
}

// MARK: - EditorFocusEvent

enum EditorFocusEvent: Equatable {
  case otherNode(id: UUID, caret: Int)
  case clear
}
