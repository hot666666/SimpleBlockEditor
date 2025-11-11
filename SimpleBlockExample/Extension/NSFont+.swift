//
//  NSFont+BlockMetrics.swift
//  SimpleBlockExample
//
//  Created by hs on 11/4/25.
//

import AppKit

extension NSFont {
  var blockLineHeight: CGFloat {
    ceil(ascender - descender + leading)
  }
}
