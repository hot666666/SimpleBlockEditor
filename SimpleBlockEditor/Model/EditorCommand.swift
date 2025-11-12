//
//  EditorCommand.swift
//  SimpleBlockEditor
//
//  Created by hs on 10/29/25.
//

import Foundation

/// 편집 정책이 텍스트 뷰에 전달하는 단일 명령 묶음입니다.
struct EditorCommand {
  /// 현재 문자열 맨 앞에서 제거할 UTF16 길이 (예: "# " → 2)
  var removePrefixUTF16: Int?
  /// 캐럿 이동 위치
  var setCaretUTF16: Int?
  /// 다른 노드로 포커스 전환 명령
  var requestFocusChange: EditorFocusEvent?
  /// 텍스트 삽입 명령
  var insertText: String?
  /// 임의의 범위 교체 명령 (보다 세밀한 제어용)
  var replaceRange: (range: NSRange, text: String)?
}
