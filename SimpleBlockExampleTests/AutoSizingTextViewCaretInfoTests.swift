import AppKit
import Testing

@testable import SimpleBlockExample

// MARK: - Tests that AutoSizingTextView(AppKit) captures and reports caret info correctly in EditorEvents.

@MainActor
@Suite("AutoSizingTextViewCaretInfoTests")
struct AutoSizingTextViewCaretInfoTests {
	@Test("Return at tail emits tail caret info")
	func returnKeyAtTailEmitsTailCaretInfo() {
		let textView = makeTextView(text: "Hello", selection: NSRange(location: 5, length: 0))
		var captured: EditorEvent?
		let delegate = InteractionProbe()
		delegate.decideHandler = { event in
			captured = event
			return nil
		}
		textView.interactionDelegate = delegate

		guard let event = makeKeyEvent(keyCode: 36, characters: "\r") else {
			Issue.record("Failed to create return key event")
			return
		}

		textView.keyDown(with: event)

		guard let captured else {
			Issue.record("Expected an EditorEvent but none was captured")
			return
		}

		switch captured {
		case let .enter(info, isTail):
			#expect(isTail)
			expectSingleLineCaret(
				info,
				selection: NSRange(location: 5, length: 0),
				caret: 5,
				stringLength: 5,
				isTail: true
			)
		default:
			Issue.record("Expected an enter event but received \(captured)")
		}
	}

	@Test("Return inside text captures caret metrics")
	func returnKeyInsideTextCapturesCaretMetrics() {
		let textView = makeTextView(text: "Hello world", selection: NSRange(location: 5, length: 0))
		var captured: EditorEvent?
		let delegate = InteractionProbe()
		delegate.decideHandler = { event in
			captured = event
			return nil
		}
		textView.interactionDelegate = delegate

		guard let event = makeKeyEvent(keyCode: 36, characters: "\r") else {
			Issue.record("Failed to create return key event")
			return
		}

		textView.keyDown(with: event)

		guard let captured else {
			Issue.record("Expected an EditorEvent but none was captured")
			return
		}

		switch captured {
		case let .enter(info, isTail):
			#expect(!isTail)
			expectSingleLineCaret(
				info,
				selection: NSRange(location: 5, length: 0),
				caret: 5,
				stringLength: 11,
				isTail: false
			)
		default:
			Issue.record("Expected an enter event but received \(captured)")
		}
	}

	@Test("Space uses pre-insert caret snapshot")
	func spaceKeyUsesPreInsertCaretSnapshot() {
		let textView = makeTextView(text: "##", selection: NSRange(location: 2, length: 0))
		var captured: EditorEvent?
		let delegate = InteractionProbe()
		delegate.decideHandler = { event in
			captured = event
			return nil
		}
		textView.interactionDelegate = delegate

		guard let event = makeKeyEvent(keyCode: 49, characters: " ") else {
			Issue.record("Failed to create space key event")
			return
		}

		textView.keyDown(with: event)

		guard let captured else {
			Issue.record("Expected an EditorEvent but none was captured")
			return
		}

		switch captured {
		case let .space(info):
			expectSingleLineCaret(
				info,
				selection: NSRange(location: 2, length: 0),
				caret: 2,
				stringLength: 2,
				isTail: true
			)
		default:
			Issue.record("Expected a space event but received \(captured)")
		}

		#expect(textView.string == "## ")
	}

	@Test("Left arrow at start reports start caret info")
	func leftArrowAtStartReportsStartCaretInfo() {
		let textView = makeTextView(text: "Hello", selection: NSRange(location: 0, length: 0))
		var captured: EditorEvent?
		let delegate = InteractionProbe()
		delegate.decideHandler = { event in
			captured = event
			return nil
		}
		textView.interactionDelegate = delegate

		let leftArrow = String(UnicodeScalar(Int(NSLeftArrowFunctionKey))!)
		guard let event = makeKeyEvent(keyCode: 123, characters: leftArrow) else {
			Issue.record("Failed to create left arrow key event")
			return
		}

		textView.keyDown(with: event)

		guard let captured else {
			Issue.record("Expected an EditorEvent but none was captured")
			return
		}

		switch captured {
		case let .arrowLeft(info):
			expectSingleLineCaret(
				info,
				selection: NSRange(location: 0, length: 0),
				caret: 0,
				stringLength: 5,
				isTail: false
			)
			#expect(info.isAtStart)
		default:
			Issue.record("Expected a left arrow event but received \(captured)")
		}
	}

	@Test("Arrow up on first line exposes total lines")
	func arrowUpOnFirstLineExposesTotalLines() {
		let textView = makeTextView(text: "Hello\nWorld", selection: NSRange(location: 1, length: 0))
		var captured: EditorEvent?
		let delegate = InteractionProbe()
		delegate.decideHandler = { event in
			captured = event
			return nil
		}
		textView.interactionDelegate = delegate

		let upArrow = String(UnicodeScalar(Int(NSUpArrowFunctionKey))!)
		guard let event = makeKeyEvent(keyCode: 126, characters: upArrow) else {
			Issue.record("Failed to create up arrow key event")
			return
		}

		textView.keyDown(with: event)

		guard let captured else {
			Issue.record("Expected an EditorEvent but none was captured")
			return
		}

		switch captured {
		case let .arrowUp(info):
			expectCaret(
				info,
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
			)
		default:
			Issue.record("Expected an up arrow event but received \(captured)")
		}
	}
}

@MainActor
private func makeTextView(text: String, selection: NSRange) -> AutoSizingTextView {
	let textView = AutoSizingTextView(frame: .zero)
	textView.isEditable = true
	textView.string = text
	textView.setSelectedRange(selection)
	return textView
}

@MainActor
private func makeKeyEvent(keyCode: UInt16, characters: String, modifiers: NSEvent.ModifierFlags = []) -> NSEvent? {
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

// Simple, one-line cases like “Hello” or “##” before space
private func expectSingleLineCaret(
	_ info: CaretInfo,
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
	if isTail {
		#expect(info.isAtTail)
	} else {
		#expect(!info.isAtTail)
	}
}

// Multi-line scenarios (e.g., “Hello\nWorld”)
private func expectCaret(
	_ info: CaretInfo,
	selection: NSRange,
	utf16: Int,
	grapheme: Int,
	stringLength: Int,
	utf16Length: Int,
	currentLineIndex: Int,
	totalLineCount: Int,
	lineRangeUTF16: NSRange,
	columnUTF16: Int,
	columnGrapheme: Int
) {
	#expect(info.selection == selection)
	#expect(info.utf16 == utf16)
	#expect(info.grapheme == grapheme)
	#expect(info.stringLength == stringLength)
	#expect(info.utf16Length == utf16Length)
	#expect(info.currentLineIndex == currentLineIndex)
	#expect(info.totalLineCount == totalLineCount)
	#expect(info.lineRangeUTF16 == lineRangeUTF16)
	#expect(info.columnUTF16 == columnUTF16)
	#expect(info.columnGrapheme == columnGrapheme)
}

private final class InteractionProbe: NSObject, TextEditorInteractionDelegate {
	var decideHandler: ((EditorEvent) -> EditCommand?)?
	var focusHandler: ((FocusChange) -> Void)?
	var willMoveHandler: ((NSWindow?) -> Void)?

	func textEditor(_ textView: AutoSizingTextView, decide event: EditorEvent) -> EditCommand? {
		decideHandler?(event)
	}

	func textEditor(_ textView: AutoSizingTextView, didRequestFocusChange change: FocusChange) {
		focusHandler?(change)
	}

	func textEditor(_ textView: AutoSizingTextView, willMoveToWindow newWindow: NSWindow?) {
		willMoveHandler?(newWindow)
	}
}
