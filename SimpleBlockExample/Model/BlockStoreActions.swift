//
//  BlockStoreActions.swift
//  SimpleBlockExample
//
//  Created by hs on 11/3/25.
//

struct BlockStoreActions {
	var onInsert: ((BlockNode, Int) -> Void)?
	var onUpdate: ((BlockNode, Int) -> Void)?
	var onRemove: ((BlockNode, Int) -> Void)?
	var onMerge: ((BlockNode, BlockNode) -> Void)?

	init(
		onInsert: ((BlockNode, Int) -> Void)? = nil,
		onUpdate: ((BlockNode, Int) -> Void)? = nil,
		onRemove: ((BlockNode, Int) -> Void)? = nil,
		onMerge: ((BlockNode, BlockNode) -> Void)? = nil
	) {
		self.onInsert = onInsert
		self.onUpdate = onUpdate
		self.onRemove = onRemove
		self.onMerge = onMerge
	}
}
