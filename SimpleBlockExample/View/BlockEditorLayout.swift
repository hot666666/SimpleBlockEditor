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

	static let `default` = BlockEditorLayout(
		gutterSize: CGSize(width: 18, height: 18),
		gutterSpacing: 4,
		textInsets: NSSize(width: 0, height: 2)
	)

	func centerPadding(for kind: BlockKind, font: NSFont) -> CGFloat {
		guard kind.usesGutter else { return 0 }

		let ascender = CGFloat(font.ascender)
		let descender = abs(CGFloat(font.descender))
		let lineHeight = ascender + descender + CGFloat(font.leading)

		let textCenter = textInsets.height + lineHeight / 2
		let gutterCenter = gutterSize.height / 2

		return max(textCenter - gutterCenter, 0)
	}
}
