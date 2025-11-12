//
//  BlockNode.swift
//  SimpleBlockExample
//
//  Created by hs on 11/1/25.
//

import SwiftUI

// MARK: - BlockKind

enum BlockKind: Equatable {
  case paragraph
  case heading(level: Int)
  case bullet
  case ordered
  case todo(checked: Bool)

  var usesGutter: Bool {
    switch self {
    case .bullet, .ordered, .todo: true
    case .paragraph, .heading: false
    }
  }
}

// MARK: - BlockNode

// TODO: - 모델 정의와 id 처리
final class BlockNode: Identifiable, Equatable {
  let id = UUID()
  var kind: BlockKind
  var text: String
  var listNumber: Int?

  init(kind: BlockKind = .paragraph, text: String = "", listNumber: Int? = nil) {
    self.kind = kind
    self.text = text
    self.listNumber = listNumber
  }

  static func == (lhs: BlockNode, rhs: BlockNode) -> Bool {
    lhs.id == rhs.id
  }
}

extension BlockNode {
  var style: BlockNodeStyle {
    BlockNodeStyle(kind: kind)
  }
}

extension BlockNode {
  static let stubs: [BlockNode] = [
    BlockNode(kind: .heading(level: 1), text: "제목"),
    BlockNode(kind: .todo(checked: false), text: "체크1"),
    BlockNode(kind: .todo(checked: false), text: "체크2 "),
  ]
}
