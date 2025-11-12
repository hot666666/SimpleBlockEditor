//
//  BlockStoreImpl.swift
//  SimpleBlockEditor
//
//  Created by hs on 11/3/25.
//

import Foundation

final class DefaultBlockStore: BlockStore {
  /// 프리뷰용 기본 블록 하나를 반환합니다.
  func load() async -> [BlockNode] { [
		BlockNode(id: UUID(), kind: .heading(level: 1), text: "이것은 제목")
	] }

  /// 외부 변경이 없으므로 즉시 종료되는 스트림을 제공합니다.
  func updates() -> AsyncStream<BlockStoreEvent> {
    AsyncStream { continuation in
      continuation.finish()
    }
  }

  /// 단순 로그 출력을 통해 이벤트 흐름을 확인합니다.
  func apply(_ event: BlockStoreEvent) async {
    switch event {
    case .inserted(let node, let at):
      print("Inserted node \(node.id) at \(at)")
    case .updated(let node, let at):
      print("Updated node \(node.id) at \(at)")
    case .removed(let node, let at):
      print("Removed node \(node.id) at \(at)")
    case .merged(let source, let target):
      print("Merged node \(source.id) into \(target.id)")
    case .replaced(let newNodes):
      print("Replaced all nodes with \(newNodes.count) new nodes")
    }
  }
}
