//
//  NSFont+BlockMetrics.swift
//  SimpleBlockEditor
//
//  Created by hs on 11/4/25.
//

import AppKit

extension NSFont {
  /// 블록 에디터에서 줄 간격을 계산할 때 사용하는 높이입니다.
  var blockLineHeight: CGFloat {
    ceil(ascender - descender + leading)
  }
}
