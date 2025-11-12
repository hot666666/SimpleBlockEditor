//
//  ContentView.swift
//  SimpleBlockEditor
//
//  Created by hs on 10/28/25.
//

import SwiftUI

struct ContentView: View {
  @State private var manager = EditorBlockManager()

  var body: some View {
		VStack {
			BlockEditorHost(manager: manager)
			Spacer()
		}
		.padding()
  }
}

#Preview {
  ContentView()
    .background(.ultraThinMaterial)
    .frame(width: 300, height: 300)
    .padding()
}
