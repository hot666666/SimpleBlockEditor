//
//  EditorRegistry.swift
//  SimpleBlockExample
//
//  Created by hs on 10/30/25.
//

import AppKit

final class EditorRegistry {
  static let shared = EditorRegistry()
  private init() {}

  private let map = NSMapTable<NSString, AutoSizingTextView>(
    keyOptions: .strongMemory,
    valueOptions: .weakMemory
  )

  func register(nodeID: UUID, view: AutoSizingTextView) {
    map.setObject(view, forKey: nodeID.uuidString as NSString)
  }

  func unregister(nodeID: UUID) {
    map.removeObject(forKey: nodeID.uuidString as NSString)
  }

  func view(for nodeID: UUID) -> AutoSizingTextView? {
    map.object(forKey: nodeID.uuidString as NSString)
  }

  func makeFirstResponder(nodeID: UUID, caret: Int? = nil) {
		guard let v = view(for: nodeID) else { return }

		v.isEditable = true
    if let caret {
      let maxLen = (v.string as NSString).length
      let pos = max(0, min(caret, maxLen))
      v.setSelectedRange(NSRange(location: pos, length: 0))
    }
    v.window?.makeFirstResponder(v)
  }
}
