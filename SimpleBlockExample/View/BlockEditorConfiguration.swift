//
//  BlockEditorConfiguration.swift
//  SimpleBlockExample
//
//  Created by hs on 2/5/26.
//

import SwiftUI

typealias BlockGutterProvider = (BlockNode, Binding<BlockKind>) -> AnyView?

struct BlockEditorConfiguration {
	var layout: BlockEditorLayout
	var gutter: BlockGutterProvider
	var policy: any BlockEditingPolicy
	var storeActions: BlockStoreActions
	var initialNodes: () -> [BlockNode]

	init(
		layout: BlockEditorLayout = .standard,
		gutter: @escaping BlockGutterProvider = DefaultBlockGutterProvider().make,
		policy: any BlockEditingPolicy = DefaultBlockEditingPolicy(),
		storeActions: BlockStoreActions = BlockStoreActions(),
		initialNodes: @escaping () -> [BlockNode] = BlockEditorConfiguration.defaultNodes
	) {
		self.layout = layout
		self.gutter = gutter
		self.policy = policy
		self.storeActions = storeActions
		self.initialNodes = initialNodes
	}

	static func standard() -> BlockEditorConfiguration {
		BlockEditorConfiguration()
	}

	private static func defaultNodes() -> [BlockNode] {
		[
			BlockNode(kind: .heading(level: 1), text: "이것은 제목"),
			BlockNode(kind: .todo(checked: false), text: "할일1"),
			BlockNode(kind: .todo(checked: false), text: "할일2 ")
		]
	}
}

struct DefaultBlockGutterProvider {
	func make(node: BlockNode, kind: Binding<BlockKind>) -> AnyView? {
		guard node.kind.usesGutter else { return nil }

		switch kind.wrappedValue {
		case .bullet:
			return AnyView(
				Image(systemName: "circle.fill")
					.font(.system(size: 6))
			)

		case .ordered:
			let numberText = "\(node.listNumber ?? 1)."
			return AnyView(
				Text(verbatim: numberText)
					.monospacedDigit()
					.font(.system(size: 12))
			)

		case .todo(let checked):
			return AnyView(
				Button {
					kind.wrappedValue = .todo(checked: !checked)
				} label: {
					Image(systemName: checked ? "checkmark.square.fill" : "square")
				}
				.buttonStyle(.plain)
			)

		default:
			return nil
		}
	}
}

