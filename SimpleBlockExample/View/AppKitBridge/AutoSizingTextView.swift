//
//  AutoSizingTextView.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import AppKit

protocol TextEditorInteractionDelegate: AnyObject {
	func textEditor(_ textView: AutoSizingTextView, decide event: EditorEvent) -> EditCommand?
	func textEditor(_ textView: AutoSizingTextView, didRequestFocusChange change: FocusChange)
	func textEditor(_ textView: AutoSizingTextView, willMoveToWindow newWindow: NSWindow?)
}

final class AutoSizingTextView: NSTextView {
	weak var interactionDelegate: TextEditorInteractionDelegate?
	
	// 사용자가 편집을 취소할 수 있게 해주는 Undo 그룹화 헬퍼
	func withUndoGroup(_ body: () -> Void) {
		undoManager?.beginUndoGrouping()
		body()
		undoManager?.endUndoGrouping()
	}
	
	// 입력 위치 정보
	private func caretInfo() -> CaretInfo {
		CaretInfo.make(from: self)
	}
	
	// 자동 크기 조정
	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		layoutManager?.usesFontLeading = true
		textContainer?.widthTracksTextView = true
		textContainer?.containerSize = .init(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
		textContainer?.lineFragmentPadding = 0
	}
	
	// 자동 높이 계산
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
	
	// 텍스트 변경 시 크기 갱신
	override func didChangeText() {
		super.didChangeText()
		invalidateIntrinsicContentSize()
	}
	
	// 프레임 크기 변경 시 텍스트 컨테이너 너비 갱신
	override func setFrameSize(_ newSize: NSSize) {
		super.setFrameSize(newSize)
		textContainer?.containerSize.width = newSize.width
		invalidateIntrinsicContentSize()
	}
	
	// 포커스 해제 시 편집 불가 모드로 전환
	override func resignFirstResponder() -> Bool {
		let ok = super.resignFirstResponder()
		let loc = selectedRange.location
		setSelectedRange(NSRange(location: loc, length: 0))
		isEditable = false
		return ok
	}
	
	// 뷰 제거 시 레지스트리에서 해제
	override func viewWillMove(toWindow newWindow: NSWindow?) {
		super.viewWillMove(toWindow: newWindow)
		interactionDelegate?.textEditor(self, willMoveToWindow: newWindow)
	}
}

// MARK: - 명령 적용 처리

private extension AutoSizingTextView {
	func applyCommand(_ command: EditCommand, groupTextEdits: Bool = false) {
		let performEdits = {
			self.applyTextEdits(from: command)
			self.applyCaretPosition(from: command)
		}
		
		if groupTextEdits {
			withUndoGroup(performEdits)
		} else {
			performEdits()
		}
		
		applyFocusChange(from: command)
	}
	
	func requestFocusChange(for dir: ArrowDir, info: CaretInfo) -> Bool {
		let event: EditorEvent
		switch dir {
		case .up: event = .arrowUp(info)
		case .down: event = .arrowDown(info)
		case .left: event = .arrowLeft(info)
		case .right: event = .arrowRight(info)
		}
		guard let delegate = interactionDelegate,
					let cmd = delegate.textEditor(self, decide: event) else { return false }
		applyCommand(cmd)
		return true
	}
	
	func applyTextEdits(from command: EditCommand) {
		if let replacement = command.replaceRange {
			edit(range: replacement.range, replacement: replacement.text)
		}
		if let insertion = command.insertText {
			super.insertText(insertion, replacementRange: selectedRange())
		}
		if let remove = command.removePrefixUTF16, remove > 0 {
			removePrefixUTF16(remove)
		}
	}
	
	func applyCaretPosition(from command: EditCommand) {
		guard let caret = command.setCaretUTF16 else { return }
		moveCaret(toUTF16: caret)
	}
	
	func applyFocusChange(from command: EditCommand) {
		guard let change = command.requestFocusChange else { return }
		interactionDelegate?.textEditor(self, didRequestFocusChange: change)
	}
}

// MARK: - 마우스 입력 처리

extension AutoSizingTextView {
	override func mouseDown(with event: NSEvent) {
		// 클릭 시 이전 포커스 해제 명령 적용
		interactionDelegate?.textEditor(self, didRequestFocusChange: .clear)
		// 편집 가능 상태로 전환
		isEditable = true
		super.mouseDown(with: event)
	}
}

// MARK: - 키보드 입력 처리

extension AutoSizingTextView {
	// MARK: - keyDown 재정의: Enter, Shift+Enter, 방향키
	/*
	 Keyboard → keyDown(with:)
	 ↓
	 [직접처리 return] 또는
	 ↓
	 super.keyDown(with:)
	 ↓
	 interpretKeyEvents(_:)
	 ├── 문자입력  → insertText(_:)
	 └── 명령입력  → doCommand(by:)
				├─ insertNewline(_:) → handleEnter
				├─ deleteBackward(_:) → handleDelete
				└─ ...
	 */
	override func keyDown(with event: NSEvent) {
		// IME 조합 중이면 시스템으로 위임(중간조합 보호)
		if hasMarkedText() {
			interpretKeyEvents([event])
			return
		}
		
		let key = Key(rawValue: event.keyCode)
		switch key {
		case .returnKey, .keypadEnter:
			event.modifierFlags.contains(.shift) ? handleSoftBreak() : handleEnter()
			return
			
		case .up:
			handleVerticalArrow(.up, event: event)
			return
			
		case .down:
			handleVerticalArrow(.down, event: event)
			return
			
		case .left:
			handleHorizontalArrow(.left, event: event)
			return
			
		case .right:
			handleHorizontalArrow(.right, event: event)
			return
			
		case .space:
			handleSpace()
			return
			
		case .delete:
			if isAtStartWithoutSelection {
				handleDeleteBackward()
				return
			}
			
		default:
			break
		}
		
		super.keyDown(with: event)
	}
}

// MARK: - Handlers

private extension AutoSizingTextView {
	enum ArrowDir { case up, down, left, right }
	
	enum Key: UInt16 {
		case returnKey  = 36
		case space = 49
		case delete = 51
		case keypadEnter = 76
		case left = 123
		case right = 124
		case down = 125
		case up = 126
	}
	
	// Enter 입력 처리: 정책 훅 호출
	func handleEnter() {
		let info = caretInfo()
		
		if let delegate = interactionDelegate,
			 let cmd = delegate.textEditor(self, decide: .enter(info, info.isAtTail)) {
			applyCommand(cmd)
		} else {
			super.insertNewline(nil)
		}
	}
	
	// Shift+Enter 입력 처리: 소프트 브레이크
	func handleSoftBreak() {
		super.insertLineBreak(nil)
	}
	
	// Backspace 입력 처리
	func handleDeleteBackward() {
		if let delegate = interactionDelegate,
			 let cmd = delegate.textEditor(self, decide: .deleteAtStart) {
			applyCommand(cmd)
		} else {
			super.deleteBackward(nil)
		}
	}
	
	// Space 입력 처리: 사용자 입력을 반영한 뒤 정책적 수정 수행
	func handleSpace() {
		let info = caretInfo()
		let range = info.selection
		
		withUndoGroup {
			// 1) 사용자의 space 입력 먼저 반영
			super.insertText(" ", replacementRange: range)
		}
		
		guard let delegate = interactionDelegate,
					let cmd = delegate.textEditor(self, decide: .space(info)) else { return }
		
		// 2) 정책적 후처리: 공통 command 경로로 처리
		applyCommand(cmd, groupTextEdits: true)
	}
	
	// 상하 방향키 입력 처리
	func handleVerticalArrow(_ dir: ArrowDir, event: NSEvent) {
		let info = caretInfo()
		
		if info.hasSelection {
			super.keyDown(with: event)
			return
		}
		
		switch dir {
		case .up where info.totalLineCount > 1 && !info.isAtFirstLine:
			super.keyDown(with: event)
			return
		case .down where info.totalLineCount > 1 && !info.isAtLastLine:
			super.keyDown(with: event)
			return
		default:
			break
		}
		
		if requestFocusChange(for: dir, info: info) == false {
			super.keyDown(with: event)
		}
	}
	
	// 좌우 방향키 입력 처리
	func handleHorizontalArrow(_ dir: ArrowDir, event: NSEvent) {
		let info = caretInfo()
		
		if info.hasSelection {
			super.keyDown(with: event)
			return
		}
		
		switch dir {
		case .left where info.isAtStart:
			if requestFocusChange(for: dir, info: info) == false {
				super.keyDown(with: event)
			}
		case .right where info.isAtTail:
			if requestFocusChange(for: dir, info: info) == false {
				super.keyDown(with: event)
			}
		default:
			super.keyDown(with: event)
		}
	}
}

// MARK: - 편집 헬퍼

private extension AutoSizingTextView {
	// 현재 텍스트의 UTF-16 코드 유닛 길이
	var lengthUTF16: Int { (self.string as NSString).length }
	
	// 선택 영역이 없고 맨 앞에 있는지 여부
	var isAtStartWithoutSelection: Bool {
		let ns = selectedRange()
		return ns.length == 0 && ns.location == 0
	}
	
	// shouldChangeText → replace → didChangeText 규약
	@discardableResult
	func edit(range: NSRange, replacement: String) -> Bool {
		guard shouldChangeText(in: range, replacementString: replacement) else { return false }
		textStorage?.replaceCharacters(in: range, with: replacement)
		didChangeText()
		return true
	}
	
	// 앞에서부터 n UTF-16 코드 유닛 삭제 (이모지/조합문자 안전: 시스템 API 경유)
	func removePrefixUTF16(_ n: Int) {
		guard n > 0 else { return }
		let cur = lengthUTF16
		guard cur > 0 else { return }
		let len = min(n, cur)
		_ = edit(range: NSRange(location: 0, length: len), replacement: "")
	}
	
	// 캐럿을 UTF-16 위치로 이동
	func moveCaret(toUTF16 pos: Int) {
		let clamped = max(0, min(pos, lengthUTF16))
		setSelectedRange(NSRange(location: clamped, length: 0))
	}
}

// MARK: - CaretInfo 생성

private extension CaretInfo {
	static func make(from textView: NSTextView) -> CaretInfo {
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
				
				if caretUTF16 >= rangeStart && (caretUTF16 <= rangeEnd || (isLastLine && caretUTF16 == rangeEnd)) {
					currentLineIndex = idx
					lineRangeUTF16 = NSRange(location: rangeStart, length: lineLengthUTF16)
					break
				}
				
				processedUTF16 = rangeEnd + 1 // include newline
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
		
		return CaretInfo(
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
