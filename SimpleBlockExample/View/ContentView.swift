//
//  ContentView.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import SwiftUI

struct ContentView: View {
	@State private var doc = BlockManager()
	
	var body: some View {
		List {
			ForEach(doc.nodes) { node in
				BlockRowEditor(doc: doc, node: node)
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
