//
//  BlockEditingPolicy.swift
//  SimpleBlockExample
//
//  Created by hs on 11/12/25.
//

// MARK: - BlockEditingContext

/// Policy에서 이용 될 Context
protocol BlockEditingContext {
  func index(of node: BlockNode) -> Int?
  func previousNode(of node: BlockNode) -> BlockNode?
  func nextNode(of node: BlockNode) -> BlockNode?
  func insertNode(_ node: BlockNode, at index: Int)
  func removeNode(at index: Int)
  func notifyUpdate(of node: BlockNode)
  func notifyMerge(from source: BlockNode, into target: BlockNode)
}

// MARK: - BlockEditingPolicy

protocol BlockEditingPolicy {
  func makeEditorCommand(for event: EditorKeyEvent, node: BlockNode, in context: BlockEditingContext)
    -> EditorCommand?
}
