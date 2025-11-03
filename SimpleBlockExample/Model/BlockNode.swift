//
//  BlockNode.swift
//  SimpleBlockExample
//
//  Created by hs on 11/1/25.
//

import SwiftUI

@Observable
final class BlockNode: Identifiable, Equatable {
	let id = UUID()
	var kind: BlockKind
	var text: String
	var listNumber: Int?
	
	init(kind: BlockKind = .paragraph, text: String = "", listNumber: Int? = nil) {
		self.kind = kind
		self.text = text
		self.listNumber = listNumber
	}
	
	static func == (l: BlockNode, r: BlockNode) -> Bool {
		l.id == r.id
	}
}

extension BlockNode {
	static let stubs: [BlockNode] = [
		BlockNode(kind: .heading(level: 1), text: "제목"),
		BlockNode(kind: .todo(checked: false), text: "체크1"),
		BlockNode(kind: .todo(checked: false), text: "체크2 ")
	]
}
