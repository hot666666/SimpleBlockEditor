//
//  BlockNode.swift
//  SimpleBlockEditor
//
//  Created by hs on 11/1/25.
//

import SwiftUI

// MARK: - BlockKind

/// 편집 화면에서 지원하는 블록 유형을 정의합니다.
enum BlockKind: Equatable {
  /// 일반 본문 문단입니다.
  case paragraph
  /// 레벨에 따라 크기가 달라지는 헤더입니다.
  case heading(level: Int)
  /// 불릿 목록 항목입니다.
  case bullet
  /// 숫자 목록 항목입니다.
  case ordered
  /// 체크 표시 가능한 할 일 항목입니다.
  case todo(checked: Bool)

  /// 해당 블록이 여백 표시(번호·체크박스 등)를 사용하는지 여부입니다.
  var usesGutter: Bool {
    switch self {
    case .bullet, .ordered, .todo: true
    case .paragraph, .heading: false
    }
  }
}

// MARK: - BlockNode

/// 사용자가 편집하는 단일 블록을 나타내는 뷰 모델입니다.
final class BlockNode: Identifiable, Equatable {
  /// 뷰 갱신을 위한 고유 식별자입니다.
  let id: UUID
  /// 표시할 블록 종류입니다.
  var kind: BlockKind
  /// 사용자가 입력한 텍스트 본문입니다.
  var text: String
  /// 순서형 목록에서 사용할 번호 캐시입니다.
  var listNumber: Int?

  init(id: UUID = UUID(), kind: BlockKind = .paragraph, text: String = "", listNumber: Int? = nil) {
    self.id = id
    self.kind = kind
    self.text = text
    self.listNumber = listNumber
  }

  static func == (lhs: BlockNode, rhs: BlockNode) -> Bool {
    lhs.id == rhs.id
  }
}

extension BlockNode {
  /// 현재 종류에 맞는 스타일 정보를 계산합니다.
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
