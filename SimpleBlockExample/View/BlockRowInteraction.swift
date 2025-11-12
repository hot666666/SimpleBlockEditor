//
//  BlockRowInteraction.swift
//  SimpleBlockExample
//
//  Created by hs on 11/10/25.
//

import AppKit

enum BlockRowKeyAction {
  case policy(EditorKeyEvent)
  case insertSpace(info: BlockCaretInfo)
  case softBreak
}

struct BlockRowInputRouter {
  func action(for event: NSEvent, textView: BlockTextView) -> BlockRowKeyAction? {
    guard let key = Key(rawValue: event.keyCode) else { return nil }

    switch key {
    case .returnKey, .keypadEnter:
      if event.modifierFlags.contains(.shift) {
        return .softBreak
      }
      let info = textView.caretInfo()
      return .policy(.returnKey(info: info, isAtTail: info.isAtTail))

    case .space:
      return .insertSpace(info: textView.caretInfo())

    case .delete:
      let info = textView.caretInfo()
      return info.isAtStart ? .policy(.backspaceAtStart) : nil

    case .up:
      return actionForVertical(direction: .up, textView: textView)

    case .down:
      return actionForVertical(direction: .down, textView: textView)

    case .left:
      return actionForHorizontal(direction: .left, textView: textView)

    case .right:
      return actionForHorizontal(direction: .right, textView: textView)
    }
  }

  private func actionForVertical(direction: VerticalDir, textView: BlockTextView) -> BlockRowKeyAction? {
    let info = textView.caretInfo()

    if info.hasSelection {
      return nil
    }

    switch direction {
    case .up where info.totalLineCount > 1 && !info.isAtFirstLine:
      return nil
    case .down where info.totalLineCount > 1 && !info.isAtLastLine:
      return nil
    default:
      break
    }

    let event: EditorKeyEvent = (direction == .up) ? .arrowUpKey(info: info) : .arrowDownKey(info: info)
    return .policy(event)
  }

  private func actionForHorizontal(direction: HorizontalDir, textView: BlockTextView) -> BlockRowKeyAction? {
    let info = textView.caretInfo()

    if info.hasSelection {
      return nil
    }

    switch direction {
    case .left where info.isAtStart:
      return .policy(.arrowLeftKey(info: info))
    case .right where info.isAtTail:
      return .policy(.arrowRightKey(info: info))
    default:
      return nil
    }
  }
}

// MARK: - Private helpers

extension BlockRowInputRouter {
  fileprivate enum Key: UInt16 {
    case returnKey = 36
    case space = 49
    case delete = 51
    case keypadEnter = 76
    case left = 123
    case right = 124
    case down = 125
    case up = 126
  }

  fileprivate enum VerticalDir { case up, down }
  fileprivate enum HorizontalDir { case left, right }
}
