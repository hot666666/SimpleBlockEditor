//
//  BlockEditorLayout.swift
//  SimpleBlockExample
//
//  Created by hs on 2/5/26.
//

import SwiftUI

struct BlockEditorLayout {
	var gutterSize: CGSize
	var gutterSpacing: CGFloat
	var textInsets: NSSize
	var topPaddingResolver: (BlockKind) -> CGFloat

	init(
		gutterSize: CGSize,
		gutterSpacing: CGFloat,
		textInsets: NSSize,
		topPaddingResolver: @escaping (BlockKind) -> CGFloat
	) {
		self.gutterSize = gutterSize
		self.gutterSpacing = gutterSpacing
		self.textInsets = textInsets
		self.topPaddingResolver = topPaddingResolver
	}

	func topPadding(for kind: BlockKind) -> CGFloat {
		topPaddingResolver(kind)
	}
}

extension BlockEditorLayout {
	static let standard = BlockEditorLayout(
		gutterSize: .init(width: 18, height: 18),
		gutterSpacing: 4,
		textInsets: .init(width: 0, height: 2),
		topPaddingResolver: { kind in
			kind.usesGutter ? 2 : 0
		}
	)
}
