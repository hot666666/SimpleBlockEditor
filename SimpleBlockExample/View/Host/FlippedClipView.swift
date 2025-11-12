//
//  FlippedClipView.swift
//  SimpleBlockExample
//
//  Created by hs on 11/11/25.
//

import AppKit

/// 스크롤뷰 내용을 좌상단 기준 좌표로 맞추는 뒤집힌 클립 뷰입니다.
final class FlippedClipView: NSClipView {
  override var isFlipped: Bool { true }
}
