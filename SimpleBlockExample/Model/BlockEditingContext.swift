//
//  BlockEditingContext.swift
//  SimpleBlockExample
//
//  Created by hs on 11/3/25.
//

protocol BlockEditingContext: AnyObject {
	var nodes: [BlockNode] { get }
	func index(of node: BlockNode) -> Int?
	func previousNode(of node: BlockNode) -> BlockNode?
	func nextNode(of node: BlockNode) -> BlockNode?
	func insertNode(_ node: BlockNode, at index: Int)
	func removeNode(at index: Int)
	func notifyUpdate(of node: BlockNode)
	func notifyMerge(from source: BlockNode, into target: BlockNode)
}
