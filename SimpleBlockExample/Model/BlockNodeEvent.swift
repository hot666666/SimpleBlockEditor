//
//  BlockNodeEvent.swift
//  SimpleBlockExample
//
//  Created by hs on 2/15/26.
//

import Foundation

enum BlockNodeEvent: Equatable {
  case insert(node: BlockNode, index: Int)
  case update(node: BlockNode, index: Int)
  case remove(node: BlockNode, index: Int)
  case move(node: BlockNode, from: Int, to: Int)
  case focus(FocusChange)
}
