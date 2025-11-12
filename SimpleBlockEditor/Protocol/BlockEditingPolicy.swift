//
//  BlockEditingPolicy.swift
//  SimpleBlockEditor
//
//  Created by hs on 11/12/25.
//

import Foundation

// MARK: - BlockEditingContext

/// 편집 정책이 노드 배열을 조작할 때 사용하는 의도 기반 인터페이스입니다.
protocol BlockEditingContext {
  /// 주어진 노드 식별자의 현재 인덱스를 찾습니다.
  func index(of nodeID: UUID) -> Int?
  /// 식별자 기준 이전 형제 노드를 조회합니다.
  func node(before nodeID: UUID) -> BlockNode?
  /// 식별자 기준 다음 형제 노드를 조회합니다.
  func node(after nodeID: UUID) -> BlockNode?

  /// 지정 노드를 UTF-16 오프셋에서 분할하고, 새 꼬리 노드를 반환합니다.
  @discardableResult
  func split(nodeID: UUID, atUTF16 offset: Int) -> BlockNode?
  /// 새 노드를 특정 인덱스에 삽입합니다.
  func insert(node: BlockNode, at index: Int)
  /// 식별자로 노드를 제거합니다.
  func remove(nodeID: UUID)
  /// 노드 변경 사항을 시스템에 알립니다.
  func update(node: BlockNode)
  /// 주어진 노드를 이전 노드와 병합합니다.
  func merge(nodeID: UUID, into previousID: UUID)
}

// MARK: - BlockEditingPolicy

/// 키 입력을 받아 블록 편집 명령으로 변환하는 프로토콜입니다.
protocol BlockEditingPolicy {
	/// 키 이벤트를 해석해 현재 컨텍스트 기반으로 실행할 에디터 명령을 생성합니다.
  func makeEditorCommand(for event: EditorKeyEvent, node: BlockNode, in context: BlockEditingContext)
    -> EditorCommand?
}
