//
//  BlockTextView.swift
//  SimpleBlockEditor
//
//  Created by hs on 10/28/25.
//

import AppKit

/// 블록 편집에 특화된 자동 크기 조절 텍스트 뷰입니다.
final class BlockTextView: NSTextView {
  var keyEventHandler: ((NSEvent) -> Bool)?
  var pointerDidFocusHandler: ((Int) -> Void)?
  var resignedFirstResponderHandler: ((Bool) -> Void)?

  // MARK: - Layout & sizing

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    layoutManager?.usesFontLeading = true
    textContainer?.widthTracksTextView = true
    textContainer?.containerSize = .init(
      width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
    textContainer?.lineFragmentPadding = 0
  }

  override var intrinsicContentSize: NSSize {
    guard let lm = layoutManager, let tc = textContainer else { return super.intrinsicContentSize }
    lm.ensureLayout(for: tc)

    let usedRect = lm.usedRect(for: tc)
    let glyphHeight = usedRect.height
    let contentHeight: CGFloat
    if glyphHeight.isNormal && glyphHeight > 0 {
      contentHeight = glyphHeight
    } else {
      contentHeight = font?.blockLineHeight ?? 0
    }
    let padding = textContainerInset.height * 2
    return .init(width: NSView.noIntrinsicMetric, height: ceil(contentHeight + padding))
  }

  override func didChangeText() {
    super.didChangeText()
    super.invalidateIntrinsicContentSize()
  }

  override func setFrameSize(_ newSize: NSSize) {
    /// 동적 너비 변화 대응
    super.setFrameSize(newSize)
    textContainer?.containerSize.width = newSize.width
    super.invalidateIntrinsicContentSize()
  }

  // MARK: - Defocus

  override func resignFirstResponder() -> Bool {
    let ok = super.resignFirstResponder()
    let loc = selectedRange.location
    /// Caret 숨기기
    setSelectedRange(NSRange(location: loc, length: 0))
    isEditable = false
    /// Focus 핸들러에 TextView 여부 전달
    let nextResponderIsBlockTextView = window?.firstResponder is BlockTextView
    resignedFirstResponderHandler?(!nextResponderIsBlockTextView)
    return ok
  }

  // MARK: - Mouse Focus

  override func mouseDown(with event: NSEvent) {
    /// Caret 표시
    isEditable = true
    super.mouseDown(with: event)
    /// Caret position 설정
    pointerDidFocusHandler?(selectedRange.location)
  }

  // MARK: - Keyboard events

  override func keyDown(with event: NSEvent) {
    if hasMarkedText() {
      interpretKeyEvents([event])
      return
    }

    if keyEventHandler?(event) == true {
      return
    }

    super.keyDown(with: event)
  }
}

// MARK: - Editing helpers

extension BlockTextView {
  var lengthUTF16: Int {
    string.utf16.count
  }

  func edit(range: NSRange?, replacement: String) {
    let range = range ?? selectedRange()
    guard shouldChangeText(in: range, replacementString: replacement) else { return }
    /// textStorage로 text보다 더 효율적으로 편집 수행
    textStorage?.replaceCharacters(in: range, with: replacement)

    didChangeText()
  }

  func removePrefix(utf16 lengthToRemove: Int) {
    guard lengthToRemove > 0 else { return }
    let cur = lengthUTF16
    guard cur > 0 else { return }
    let len = min(lengthToRemove, cur)

    edit(range: NSRange(location: 0, length: len), replacement: "")
  }

  func moveCaret(utf16 pos: Int) {
    let clamped = max(0, min(pos, lengthUTF16))
    setSelectedRange(NSRange(location: clamped, length: 0))
  }

  // MARK: - Convenience

  func caretInfo() -> BlockCaretInfo {
    BlockCaretInfo.make(from: self)
  }
}

// MARK: - CaretInfo support

extension BlockCaretInfo {
  fileprivate static func make(from textView: NSTextView) -> BlockCaretInfo {
    let selection = textView.selectedRange()
    let string = textView.string
    let utf16Length = (string as NSString).length
    let caretUTF16 = max(0, min(selection.location, utf16Length))
    let index = String.Index(utf16Offset: caretUTF16, in: string)
    let grapheme = string.distance(from: string.startIndex, to: index)

    let lines = string.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
    let totalLineCount = max(1, lines.count)
    var currentLineIndex = 0
    var lineRangeUTF16 = NSRange(location: 0, length: 0)
    var processedUTF16 = 0

    if lines.isEmpty {
      lineRangeUTF16 = NSRange(location: 0, length: utf16Length)
    } else {
      for (idx, line) in lines.enumerated() {
        let lineString = String(line)
        let lineLengthUTF16 = (lineString as NSString).length
        let rangeStart = processedUTF16
        let rangeEnd = processedUTF16 + lineLengthUTF16
        let isLastLine = idx == lines.count - 1

        if caretUTF16 >= rangeStart
          && (caretUTF16 <= rangeEnd || (isLastLine && caretUTF16 == rangeEnd))
        {
          currentLineIndex = idx
          lineRangeUTF16 = NSRange(location: rangeStart, length: lineLengthUTF16)
          break
        }

        processedUTF16 = rangeEnd + 1
        if isLastLine {
          currentLineIndex = idx
          lineRangeUTF16 = NSRange(location: rangeStart, length: lineLengthUTF16)
        }
      }
    }

    let columnUTF16 = max(0, caretUTF16 - lineRangeUTF16.location)

    let lineStartIndex = String.Index(utf16Offset: lineRangeUTF16.location, in: string)
    let caretIndex = String.Index(utf16Offset: caretUTF16, in: string)
    let columnGrapheme = string.distance(from: lineStartIndex, to: caretIndex)

    return BlockCaretInfo(
      selection: selection,
      utf16: caretUTF16,
      grapheme: grapheme,
      stringLength: string.count,
      utf16Length: utf16Length,
      currentLineIndex: currentLineIndex,
      totalLineCount: totalLineCount,
      lineRangeUTF16: lineRangeUTF16,
      columnUTF16: columnUTF16,
      columnGrapheme: columnGrapheme
    )
  }
}
