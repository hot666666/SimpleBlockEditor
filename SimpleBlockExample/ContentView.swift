//
//  ContentView.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import SwiftUI

struct ContentView: View {
  @State private var manager = BlockManager()

  var body: some View {
    BlockEditorHost(manager: manager)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  ContentView()
    .background(.ultraThinMaterial)
    .frame(width: 300, height: 300)
    .padding()
}
