//
//  NSFont+BlockMetrics.swift
//  SimpleBlockExample
//
//  Created by hs on 11/4/25.
//

import AppKit

extension NSFont {
	/// Cached default line height that matches our AutoSizingTextView metrics.
	var blockLineHeight: CGFloat {
		BlockFontMetrics.shared.lineHeight(for: self)
	}
	
	/// Baseline offset AppKit expects for this font when usesFontLeading is disabled.
	var blockBaselineOffset: CGFloat {
		BlockFontMetrics.shared.baseline(for: self)
	}
}

fileprivate final class BlockFontMetrics {
	static let shared = BlockFontMetrics()
	
	private let layoutManager: NSLayoutManager
	private let lock = NSLock()
	
	private init() {
		let manager = NSLayoutManager()
		manager.usesFontLeading = false
		layoutManager = manager
	}
	
	func lineHeight(for font: NSFont) -> CGFloat {
		lock.lock()
		defer { lock.unlock() }
		return ceil(layoutManager.defaultLineHeight(for: font))
	}
	
	func baseline(for font: NSFont) -> CGFloat {
		lock.lock()
		defer { lock.unlock() }
		return layoutManager.defaultBaselineOffset(for: font)
	}
}
