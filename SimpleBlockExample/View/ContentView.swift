//
//  ContentView.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import SwiftUI

struct ContentView: View {
	@State private var doc: BlockManager
	private let configuration: BlockEditorConfiguration

	init(
		manager: BlockManager? = nil,
		configuration: BlockEditorConfiguration = .standard()
	) {
		self.configuration = configuration
		if let manager {
			_doc = State(initialValue: manager)
		} else {
			let manager = BlockManager(
				nodes: configuration.initialNodes(),
				policy: configuration.policy,
				storeActions: configuration.storeActions
			)
			_doc = State(initialValue: manager)
		}
	}

	var body: some View {
		List {
			ForEach(doc.nodes) { node in
				BlockRowEditor(
					doc: doc,
					node: node,
					layout: configuration.layout,
					gutter: configuration.gutter
				)
			}
			.listRowInsets(.none)
			.listRowSeparator(.hidden)
		}
		.listStyle(.plain)
	}
}

#Preview {
	ContentView()
		.background(.ultraThinMaterial)
		.frame(width: 300, height: 300)
		.padding()
}
