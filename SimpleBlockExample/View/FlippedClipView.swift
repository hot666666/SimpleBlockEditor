//
//  FlippedClipView.swift
//  SimpleBlockExample
//
//  Created by hs on 11/11/25.
//

import AppKit

// ScrollView의 좌표계를 뒤집음(상->하)
final class FlippedClipView: NSClipView {
  override var isFlipped: Bool { true }
}
