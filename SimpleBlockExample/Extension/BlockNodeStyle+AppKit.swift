//
//  BlockNodeStyle+AppKit.swift
//  SimpleBlockExample
//
//  Created by hs on 11/10/25.
//

import AppKit

extension BlockNodeStyle {
  /// 현재 스타일 정보를 기반으로 AppKit `NSFont`를 생성합니다.
  func makeAppKitFont() -> NSFont {
    NSFont.monospacedSystemFont(ofSize: font.size, weight: font.weight.appKitWeight)
  }
}

private extension BlockFontWeight {
  /// Block 전용 굵기를 AppKit 가중치로 매핑합니다.
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
