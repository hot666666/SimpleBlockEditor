//
//  BlockStore.swift
//  SimpleBlockEditor
//
//  Created by hs on 11/12/25.
//

// MARK: - BlockStoreEvent

/// 외부 스토어와 동기화할 때 사용되는 블록 변경 이벤트입니다.
enum BlockStoreEvent: Equatable {
  /// 인덱스 위치에 새 노드가 삽입되었습니다.
  case inserted(BlockNode, at: Int)
  /// 지정 노드가 업데이트되었습니다.
  case updated(BlockNode, at: Int)
  /// 인덱스 위치에서 노드가 제거되었습니다.
  case removed(BlockNode, at: Int)
  /// 두 노드가 병합되어 하나로 대체되었습니다.
  case merged(source: BlockNode, target: BlockNode)
  /// 전체 블록 배열이 새로운 내용으로 교체되었습니다.
  case replaced([BlockNode])
}

// MARK: - BlockStore

/// 블록 데이터를 영속화하거나 외부와 중계하는 저장소 인터페이스입니다.
protocol BlockStore {
  /// 스토어의 초기 상태를 로드합니다.
  func load() async -> [BlockNode]
  /// 스토어에서 발생하는 모든 이벤트 스트림을 제공합니다.
  func updates() -> AsyncStream<BlockStoreEvent>
  /// 로컬에서 발생한 변경 이벤트를 스토어에 반영합니다.
  func apply(_ event: BlockStoreEvent) async
}
