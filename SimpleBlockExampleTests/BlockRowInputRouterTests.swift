import AppKit
import Testing

@testable import SimpleBlockExample

@MainActor
@Suite("BlockRowInputRouterTests")
struct BlockRowInputRouterTests {
  private let router = BlockRowInputRouter()

  @Test("Return at tail emits tail caret info")
  func returnKeyAtTailEmitsTailCaretInfo() {
    let textView = makeTextView(text: "Hello", selection: NSRange(location: 5, length: 0))
    guard let event = makeKeyEvent(keyCode: 36, characters: "\r") else {
      Issue.record("Failed to create return key event")
      return
    }

    guard
      case .policy(.returnKey(let info, let isTail))? = router.action(for: event, textView: textView)
    else {
      Issue.record("Expected enter event")
      return
    }

    #expect(isTail)
    expectSingleLineCaret(
      info,
      selection: NSRange(location: 5, length: 0),
      caret: 5,
      stringLength: 5,
      isTail: true
    )
  }

  @Test("Return inside text captures caret metrics")
  func returnKeyInsideTextCapturesCaretMetrics() {
    let textView = makeTextView(text: "Hello world", selection: NSRange(location: 5, length: 0))
    guard let event = makeKeyEvent(keyCode: 36, characters: "\r") else {
      Issue.record("Failed to create return key event")
      return
    }

    guard
      case .policy(.returnKey(let info, let isTail))? = router.action(for: event, textView: textView)
    else {
      Issue.record("Expected enter event")
      return
    }

    #expect(!isTail)
    expectSingleLineCaret(
      info,
      selection: NSRange(location: 5, length: 0),
      caret: 5,
      stringLength: 11,
      isTail: false
    )
  }

  @Test("Space routes pre-insert caret snapshot")
  func spaceKeyRoutesCaretSnapshot() {
    let textView = makeTextView(text: "##", selection: NSRange(location: 2, length: 0))
    guard let event = makeKeyEvent(keyCode: 49, characters: " ") else {
      Issue.record("Failed to create space key event")
      return
    }

    guard case .insertSpace(let info)? = router.action(for: event, textView: textView) else {
      Issue.record("Expected space action")
      return
    }

    expectSingleLineCaret(
      info,
      selection: NSRange(location: 2, length: 0),
      caret: 2,
      stringLength: 2,
      isTail: true
    )
  }

  @Test("Left arrow at start produces arrowLeft event")
  func leftArrowAtStartProducesArrowLeft() {
    let textView = makeTextView(text: "Hello", selection: NSRange(location: 0, length: 0))
    let arrow = String(UnicodeScalar(Int(NSLeftArrowFunctionKey))!)
    guard let event = makeKeyEvent(keyCode: 123, characters: arrow) else {
      Issue.record("Failed to create left arrow key event")
      return
    }

    guard case .policy(.arrowLeftKey(let info))? = router.action(for: event, textView: textView) else {
      Issue.record("Expected arrowLeft policy")
      return
    }

    expectSingleLineCaret(
      info,
      selection: NSRange(location: 0, length: 0),
      caret: 0,
      stringLength: 5,
      isTail: false
    )
    #expect(info.isAtStart)
  }

  @Test("Arrow up on first line exposes total lines")
  func arrowUpOnFirstLineExposesTotalLines() {
    let textView = makeTextView(text: "Hello\nWorld", selection: NSRange(location: 1, length: 0))
    let arrow = String(UnicodeScalar(Int(NSUpArrowFunctionKey))!)
    guard let event = makeKeyEvent(keyCode: 126, characters: arrow) else {
      Issue.record("Failed to create up arrow key event")
      return
    }

    guard case .policy(.arrowUpKey(let info))? = router.action(for: event, textView: textView) else {
      Issue.record("Expected arrowUp policy")
      return
    }

    expectMultiLineCaret(
      info,
      expected: MultiLineCaretExpectation(
        selection: NSRange(location: 1, length: 0),
        utf16: 1,
        grapheme: 1,
        stringLength: 11,
        utf16Length: 11,
        currentLineIndex: 0,
        totalLineCount: 2,
        lineRangeUTF16: NSRange(location: 0, length: 5),
        columnUTF16: 1,
        columnGrapheme: 1
      ))
  }
}

// MARK: - Helpers

@MainActor
private func makeTextView(text: String, selection: NSRange) -> BlockTextView {
  let textView = BlockTextView(frame: .zero)
  textView.isEditable = true
  textView.string = text
  textView.setSelectedRange(selection)
  return textView
}

@MainActor
private func makeKeyEvent(
  keyCode: UInt16, characters: String, modifiers: NSEvent.ModifierFlags = []
) -> NSEvent? {
  NSEvent.keyEvent(
    with: .keyDown,
    location: .zero,
    modifierFlags: modifiers,
    timestamp: 0,
    windowNumber: 0,
    context: nil,
    characters: characters,
    charactersIgnoringModifiers: characters,
    isARepeat: false,
    keyCode: keyCode
  )
}

private func expectSingleLineCaret(
  _ info: BlockCaretInfo,
  selection: NSRange,
  caret: Int,
  stringLength: Int,
  isTail: Bool
) {
  #expect(info.selection == selection)
  #expect(info.utf16 == caret)
  #expect(info.grapheme == caret)
  #expect(info.stringLength == stringLength)
  #expect(info.utf16Length == stringLength)
  #expect(info.currentLineIndex == 0)
  #expect(info.totalLineCount == 1)
  #expect(info.lineRangeUTF16 == NSRange(location: 0, length: stringLength))
  #expect(info.columnUTF16 == caret)
  #expect(info.columnGrapheme == caret)
  isTail ? #expect(info.isAtTail) : #expect(!info.isAtTail)
}

private struct MultiLineCaretExpectation {
  let selection: NSRange
  let utf16: Int
  let grapheme: Int
  let stringLength: Int
  let utf16Length: Int
  let currentLineIndex: Int
  let totalLineCount: Int
  let lineRangeUTF16: NSRange
  let columnUTF16: Int
  let columnGrapheme: Int
}

private func expectMultiLineCaret(_ info: BlockCaretInfo, expected: MultiLineCaretExpectation) {
  #expect(info.selection == expected.selection)
  #expect(info.utf16 == expected.utf16)
  #expect(info.grapheme == expected.grapheme)
  #expect(info.stringLength == expected.stringLength)
  #expect(info.utf16Length == expected.utf16Length)
  #expect(info.currentLineIndex == expected.currentLineIndex)
  #expect(info.totalLineCount == expected.totalLineCount)
  #expect(info.lineRangeUTF16 == expected.lineRangeUTF16)
  #expect(info.columnUTF16 == expected.columnUTF16)
  #expect(info.columnGrapheme == expected.columnGrapheme)
}
