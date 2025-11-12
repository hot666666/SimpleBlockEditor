//
//  BlockNodeStyle.swift
//  SimpleBlockExample
//
//  Created by hs on 11/12/25.
//

import Foundation

/// 블록 텍스트에 사용할 폰트 크기와 두께를 묶어둔 값 객체입니다.
struct BlockFontStyle: Equatable {
  /// 포인트 단위 폰트 크기입니다.
  let size: CGFloat
  /// 대응하는 굵기 정보입니다.
  let weight: BlockFontWeight
}

/// 블록 텍스트 두께 표현입니다.
enum BlockFontWeight: Equatable {
  case regular
  case medium
  case semibold
  case bold
}

/// 블록 종류에 맞춘 타이포그래피 스타일입니다.
struct BlockNodeStyle: Equatable {
  /// 텍스트에 적용할 폰트 스타일입니다.
  var font: BlockFontStyle

  init(font: BlockFontStyle) {
    self.font = font
  }

  init(kind: BlockKind) {
    self.font = Self.font(for: kind)
  }

  /// 블록 종류별 기본 폰트 설정을 계산합니다.
  private static func font(for kind: BlockKind) -> BlockFontStyle {
    switch kind {
    case .heading(let level):
      switch level {
      case 1:
        return BlockFontStyle(size: 24, weight: .bold)
      case 2:
        return BlockFontStyle(size: 20, weight: .bold)
      case 3:
        return BlockFontStyle(size: 16, weight: .bold)
      default:
        return BlockFontStyle(size: 14, weight: .regular)
      }
    case .paragraph, .bullet, .ordered, .todo:
      return BlockFontStyle(size: 14, weight: .regular)
    }
  }
}
