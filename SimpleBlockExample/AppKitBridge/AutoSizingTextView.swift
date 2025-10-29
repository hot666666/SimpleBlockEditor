//
//  AutoSizingTextView.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import AppKit

final class AutoSizingTextView: NSTextView {
	// SwiftUI의 결정 훅
	var _decide: ((EditorEvent) -> EditCommand?)?
	
	// 입력 위치 정보
	private func caretInfo() -> CaretInfo {
		let s = self.string
		let ns = self.selectedRange()
		let utf16 = ns.location
		let idx = String.Index(utf16Offset: utf16, in: s)
		let grapheme = s.distance(from: s.startIndex, to: idx)
		return .init(utf16: utf16, grapheme: grapheme)
	}
	
	// 자동 높이 계산
  private var lineHeight: CGFloat {
    guard let f = font else { return 0 }
    return ceil(f.ascender - f.descender + f.leading)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    textContainer?.widthTracksTextView = true
    textContainer?.containerSize = .init(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
    textContainer?.lineFragmentPadding = 0
  }

  override var intrinsicContentSize: NSSize {
    guard let lm = layoutManager, let tc = textContainer else { return super.intrinsicContentSize }
    lm.ensureLayout(for: tc)
    let usedH = lm.usedRect(for: tc).integral.height
    let pad = textContainerInset.height * 2
    let h = max(usedH + pad, lineHeight + pad)
    return .init(width: NSView.noIntrinsicMetric, height: ceil(h))
  }

  override func didChangeText() {
    super.didChangeText()
    invalidateIntrinsicContentSize()
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    textContainer?.containerSize.width = newSize.width
    invalidateIntrinsicContentSize()
  }
}

extension AutoSizingTextView {
	// MARK: - keyDown 재정의: Enter/Shift+Enter 구분
	/*
	Keyboard → keyDown(with:)
							 ↓
						 [내가 처리하면 return]
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
		/// 36: Return, 76: Keypad Enter
		if event.keyCode == 36 || event.keyCode == 76 {
			if event.modifierFlags.contains(.shift) {
				handleSoftBreak()
			} else {
				handleEnter()
			}
			return
		}
		
		// 기본 처리
		super.keyDown(with: event)
	}
	
	// MARK: - 기본 입력 처리 재정의: 스페이스바 입력 시 SwiftUI 훅 호출
	override func insertText(_ insertString: Any, replacementRange: NSRange) {
		// SPACE(스페이스바): SwiftUI 훅 호출
		if let s = insertString as? String, s == " " {
			let info = caretInfo()
			// SwiftUI의 결정 훅 호출
			if let cmd = _decide?(.space(info)) {
				undoManager?.beginUndoGrouping()
				
				// 1) 사용자의 space 입력을 먼저 정상 반영
				super.insertText(s, replacementRange: replacementRange)
				
				// 2) 앞에서부터 지정 위치까지 제거
				if let remove = cmd.removePrefixUTF16, remove > 0 {
					let curLen = (string as NSString).length
					let n = min(remove, curLen)
					let range = NSRange(location: 0, length: n)
					if shouldChangeText(in: range, replacementString: "") {
						textStorage?.replaceCharacters(in: range, with: "")
						didChangeText() // textDidChange → $text 동기화
					}
				}
				// 3) 커서 이동
				setSelectedRange(NSRange(location: 0, length: 0))
				
				undoManager?.endUndoGrouping()
				return
			}
		}
		
		// 기본 처리
		super.insertText(insertString, replacementRange: replacementRange)
	}
	
	// MARK: - 기본 삭제 처리 재정의: 커서가 0이고 선택 없으면 deleteAtStart 이벤트로 병합/타입해제 결정
	override func deleteBackward(_ sender: Any?) {
		let ns = selectedRange()
		if ns.length == 0, ns.location == 0 {
			let _ = _decide?(.deleteAtStart)
			return
		}
		
		// 기본 처리
		super.deleteBackward(sender)
	}
	
	// Enter → 문서 분할
	private func handleEnter() {
		let info = caretInfo()
		let isTail = (info.grapheme == self.string.count)  // 현재 커서가 줄 끝인지
		let _ = _decide?(.enter(info, isTail))
	}
	
	// Shift+Enter → 실제 "\n" 추가
	private func handleSoftBreak() {
		// let _ = _decide?(.shiftEnter) // 정책 훅
		super.insertLineBreak(nil)
	}
}
