//
//  BlockEditorLayout.swift
//  SimpleBlockExample
//
//  Created by hs on 2/5/26.
//

import AppKit

struct BlockEditorLayout {
	let gutterSize: CGSize
	let gutterSpacing: CGFloat
	let textInsets: NSSize

	static let `default`: BlockEditorLayout = {
		let baseFont = BlockKind.paragraph.font
		return BlockEditorLayout(
			gutterSize: CGSize(width: 18, height: baseFont.blockLineHeight),
			gutterSpacing: 4,
			textInsets: NSSize(width: 0, height: 6)
		)
	}()

	func centerPadding(for kind: BlockKind, font: NSFont) -> CGFloat {
		guard kind.usesGutter else { return 0 }

		let lineHeight = font.blockLineHeight

		let textCenter = textInsets.height + lineHeight / 2
		let gutterCenter = gutterSize.height / 2

		return max(textCenter - gutterCenter - 1, 0)
	}
}
