//
//  BlockCaretInfo.swift
//  SimpleBlockExample
//
//  Created by hs on 11/11/25.
//

import Foundation

// MARK: - 입력 직전/직후 커서 정보 (utf16은 Cocoa 기준, grapheme은 Swift String 기준)

struct BlockCaretInfo {
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

  var hasSelection: Bool { selection.length > 0 }
  var isSelectionEmpty: Bool { !hasSelection }
  var isAtStart: Bool { isSelectionEmpty && utf16 == 0 }
  var isAtTail: Bool { isSelectionEmpty && grapheme == stringLength }
  var isAtFirstLine: Bool { currentLineIndex == 0 }
  var isAtLastLine: Bool { currentLineIndex == totalLineCount - 1 }

  init(
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
    self.selection = selection
    self.utf16 = utf16
    self.grapheme = grapheme
    self.stringLength = stringLength
    self.utf16Length = utf16Length
    self.currentLineIndex = currentLineIndex
    self.totalLineCount = totalLineCount
    self.lineRangeUTF16 = lineRangeUTF16
    self.columnUTF16 = columnUTF16
    self.columnGrapheme = columnGrapheme
  }
}
