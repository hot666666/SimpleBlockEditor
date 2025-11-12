//
//  BlockNodeStyle+AppKit.swift
//  SimpleBlockExample
//
//  Created by hs on 11/10/25.
//

import AppKit

extension BlockNodeStyle {
  func makeAppKitFont() -> NSFont {
    NSFont.monospacedSystemFont(ofSize: font.size, weight: font.weight.appKitWeight)
  }
}

private extension BlockFontWeight {
  var appKitWeight: NSFont.Weight {
    switch self {
    case .regular:
      return .regular
    case .medium:
      return .medium
    case .semibold:
      return .semibold
    case .bold:
      return .bold
    }
  }
}
