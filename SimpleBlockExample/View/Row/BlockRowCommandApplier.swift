//
//  BlockRowCommandApplier.swift
//  SimpleBlockExample
//
//  Created by hs on 11/12/25.
//

/// 편집 명령을 텍스트 뷰 조작으로 변환하는 유틸리티 객체입니다.
final class BlockRowCommandApplier {
  private unowned let textView: BlockTextView
  private let beforeFocusChange: () -> Void
  private let focusHandler: (EditorFocusEvent) -> Void

  init(
    textView: BlockTextView,
    beforeFocusChange: @escaping () -> Void,
    focusHandler: @escaping (EditorFocusEvent) -> Void
  ) {
    self.textView = textView
    self.beforeFocusChange = beforeFocusChange
    self.focusHandler = focusHandler
  }

  func apply(_ command: EditorCommand) {
    applyTextEdits(from: command)
    applyCaretPosition(from: command)

    if let change = command.requestFocusChange {
      beforeFocusChange()
      focusHandler(change)
    }
  }

  private func applyTextEdits(from command: EditorCommand) {
    if let replacement = command.replaceRange {
      textView.edit(range: replacement.range, replacement: replacement.text)
    }
    if let insertion = command.insertText {
      textView.edit(range: command.replaceRange?.range, replacement: insertion)
    }
    if let remove = command.removePrefixUTF16, remove > 0 {
      textView.removePrefix(utf16: remove)
    }
  }

  private func applyCaretPosition(from command: EditorCommand) {
    guard let caret = command.setCaretUTF16 else { return }
    textView.moveCaret(utf16: caret)
  }
}
