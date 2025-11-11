//
//  BlockEditorHost.swift
//  SimpleBlockExample
//
//  Created by hs on 2/9/26.
//

import SwiftUI

struct BlockEditorHost: NSViewControllerRepresentable {
  var manager: BlockManager

  func makeNSViewController(context: Context) -> BlockEditorViewController {
    BlockEditorViewController(manager: manager)
  }

  func updateNSViewController(_ controller: BlockEditorViewController, context: Context) {}
}
