//
//  BlockNodeStyle.swift
//  SimpleBlockExample
//
//  Created by hs on 11/12/25.
//

import CoreGraphics

struct BlockFontStyle: Equatable {
  let size: CGFloat
  let weight: BlockFontWeight
}

enum BlockFontWeight: Equatable {
  case regular
  case medium
  case semibold
  case bold
}

struct BlockNodeStyle: Equatable {
  var font: BlockFontStyle

  init(font: BlockFontStyle) {
    self.font = font
  }

  init(kind: BlockKind) {
    self.font = Self.font(for: kind)
  }

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
