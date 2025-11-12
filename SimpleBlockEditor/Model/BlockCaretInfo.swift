//
//  BlockCaretInfo.swift
//  SimpleBlockEditor
//
//  Created by hs on 11/11/25.
//

import Foundation

/// 블록 편집 단계에서 커서 위치와 선택 범위를 동시에 추적하는 스냅샷입니다.
struct BlockCaretInfo {
  /// Cocoa 텍스트 시스템이 넘겨주는 선택 범위입니다.
  let selection: NSRange
  /// UTF-16 코드 유닛 기준 캐럿 위치입니다.
  let utf16: Int
  /// Swift Grapheme 기준 캐럿 위치입니다.
  let grapheme: Int
  /// 현재 문자열의 전체 Grapheme 길이입니다.
  let stringLength: Int
  /// 현재 문자열의 전체 UTF-16 길이입니다.
  let utf16Length: Int
  /// 캐럿이 위치한 줄의 0 기반 인덱스입니다.
  let currentLineIndex: Int
  /// 블록 내 전체 줄 개수입니다.
  let totalLineCount: Int
  /// 캐럿이 포함된 줄의 UTF-16 범위입니다.
  let lineRangeUTF16: NSRange
  /// 줄 내 UTF-16 기준 열 위치입니다.
  let columnUTF16: Int
  /// 줄 내 Grapheme 기준 열 위치입니다.
  let columnGrapheme: Int

  /// 하나 이상의 문자 선택이 존재하는지 여부입니다.
  var hasSelection: Bool { selection.length > 0 }
  /// 선택이 없는 상태인지 여부입니다.
  var isSelectionEmpty: Bool { !hasSelection }
  /// 커서가 문자열 맨 앞에 위치했는지 여부입니다.
  var isAtStart: Bool { isSelectionEmpty && utf16 == 0 }
  /// 커서가 문자열 말단에 위치했는지 여부입니다.
  var isAtTail: Bool { isSelectionEmpty && grapheme == stringLength }
  /// 캐럿이 첫 번째 줄에 있는지 여부입니다.
  var isAtFirstLine: Bool { currentLineIndex == 0 }
  /// 캐럿이 마지막 줄에 있는지 여부입니다.
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
