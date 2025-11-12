//
//  BlockEditingPolicy.swift
//  SimpleBlockExample
//
//  Created by hs on 11/12/25.
//

// MARK: - BlockEditingContextProtocol

/// 편집 정책이 노드 배열을 조작할 때 사용하는 어댑터입니다.
protocol BlockEditingContextProtocol {
  /// 주어진 노드의 현재 인덱스를 찾습니다.
  func index(of node: BlockNode) -> Int?
  /// 노드의 이전 형제를 조회합니다.
  func previousNode(of node: BlockNode) -> BlockNode?
  /// 노드의 다음 형제를 조회합니다.
  func nextNode(of node: BlockNode) -> BlockNode?
  /// 지정 인덱스에 새 노드를 삽입합니다.
  func insertNode(_ node: BlockNode, at index: Int)
  /// 지정 인덱스의 노드를 제거합니다.
  func removeNode(at index: Int)
  /// 노드 내용이 바뀌었음을 시스템에 알립니다.
  func notifyUpdate(of node: BlockNode)
  /// 두 노드가 병합되었음을 스토어에 전달합니다.
  func notifyMerge(from source: BlockNode, into target: BlockNode)
}

// MARK: - BlockEditingPolicy

/// 키 입력을 받아 블록 편집 명령으로 변환하는 프로토콜입니다.
protocol BlockEditingPolicy {
	/// 키 이벤트를 해석해 현재 컨텍스트 기반으로 실행할 에디터 명령을 생성합니다.
  func makeEditorCommand(for event: EditorKeyEvent, node: BlockNode, in context: BlockEditingContextProtocol)
    -> EditorCommand?
}
