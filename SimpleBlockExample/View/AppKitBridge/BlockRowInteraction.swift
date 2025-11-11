//
//  BlockRowInteraction.swift
//  SimpleBlockExample
//
//  Created by hs on 11/10/25.
//

import AppKit

enum BlockRowKeyAction {
  case policy(EditorEvent)
  case insertSpace(info: CaretInfo)
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
      return .policy(.enter(info, info.isAtTail))

    case .space:
      return .insertSpace(info: textView.caretInfo())

    case .delete:
      let info = textView.caretInfo()
      return info.isAtStart ? .policy(.deleteAtStart) : nil

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

  private func actionForVertical(direction: VerticalDir, textView: BlockTextView)
    -> BlockRowKeyAction?
  {
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

    let event: EditorEvent = (direction == .up) ? .arrowUp(info) : .arrowDown(info)
    return .policy(event)
  }

  private func actionForHorizontal(direction: HorizontalDir, textView: BlockTextView)
    -> BlockRowKeyAction?
  {
    let info = textView.caretInfo()

    if info.hasSelection {
      return nil
    }

    switch direction {
    case .left where info.isAtStart:
      return .policy(.arrowLeft(info))
    case .right where info.isAtTail:
      return .policy(.arrowRight(info))
    default:
      return nil
    }
  }
}

final class BlockRowCommandApplier {
  private unowned let textView: BlockTextView
  private let beforeFocusChange: () -> Void
  private let focusHandler: (FocusChange) -> Void

  init(
    textView: BlockTextView,
    beforeFocusChange: @escaping () -> Void,
    focusHandler: @escaping (FocusChange) -> Void
  ) {
    self.textView = textView
    self.beforeFocusChange = beforeFocusChange
    self.focusHandler = focusHandler
  }

  func apply(_ command: EditCommand, groupTextEdits: Bool = false) {
    applyTextEdits(from: command)
    applyCaretPosition(from: command)

    if let change = command.requestFocusChange {
      beforeFocusChange()
      focusHandler(change)
    }
  }

  private func applyTextEdits(from command: EditCommand) {
    if let replacement = command.replaceRange {
      textView.edit(range: replacement.range, replacement: replacement.text)
    }
    if let insertion = command.insertText {
      textView.edit(range: textView.selectedRange(), replacement: insertion)
    }
    if let remove = command.removePrefixUTF16, remove > 0 {
      textView.removePrefix(utf16: remove)
    }
  }

  private func applyCaretPosition(from command: EditCommand) {
    guard let caret = command.setCaretUTF16 else { return }
    textView.moveCaret(utf16: caret)
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
