//
//  BlockEditorHost.swift
//  SimpleBlockEditor
//
//  Created by hs on 2/9/26.
//

import SwiftUI

/// SwiftUI와 AppKit 편집기를 중계하는 호스트 뷰입니다.
struct BlockEditorHost: NSViewControllerRepresentable {
  var manager: EditorBlockManager

  func makeNSViewController(context: Context) -> BlockEditorViewController {
    BlockEditorViewController(manager: manager)
  }

  func updateNSViewController(_ controller: BlockEditorViewController, context: Context) {}
}
