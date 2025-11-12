//
//  BlockStore.swift
//  SimpleBlockExample
//
//  Created by hs on 11/12/25.
//

// MARK: - BlockStoreEvent

enum BlockStoreEvent: Equatable {
  case inserted(BlockNode, at: Int)
  case updated(BlockNode, at: Int)
  case removed(BlockNode, at: Int)
  case merged(source: BlockNode, target: BlockNode)
  case replaced([BlockNode])
}

// MARK: - BlockStore

protocol BlockStore {
  func load() async -> [BlockNode]
  func updates() -> AsyncStream<BlockStoreEvent>
  func apply(_ event: BlockStoreEvent) async
}
