//
//  EditorKeyEvent.swift
//  SimpleBlockEditor
//
//  Created by hs on 10/28/25.
//

import Foundation

// MARK: - EditorBlockEvent

/// 블록 노드 배열에서 발생한 구조적 변화를 표현합니다.
enum EditorBlockEvent: Equatable {
  case insert(node: BlockNode, index: Int)
  case update(node: BlockNode, index: Int)
  case remove(node: BlockNode, index: Int)
  case move(node: BlockNode, from: Int, to: Int)
  case focus(EditorFocusEvent)
}

// MARK: - EditorKeyEvent

/// 블록 단위 키보드 입력과 커서 상태를 표현합니다.
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

/// 개별 텍스트 뷰 간 포커스 상태 변화를 나타냅니다.
enum EditorFocusEvent: Equatable {
  /// 다른 노드로 포커스를 옮기고 특정 캐럿 위치를 함께 지정합니다.
  case otherNode(id: UUID, caret: Int)
  /// 포커스를 명시적으로 해제합니다.
  case clear
}
