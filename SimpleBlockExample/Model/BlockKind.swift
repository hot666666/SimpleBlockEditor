//
//  BlockKind.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

import AppKit

enum BlockKind: Equatable {
	case paragraph
	case heading(level: Int)    // 1...3
	case bullet                 // •
	case ordered                // 1., 2., ...
	case todo(checked: Bool)
	
	var usesGutter: Bool {
		switch self {
		case .bullet, .ordered, .todo(_): true
		case .paragraph, .heading(_):     false
		}
	}
}

extension BlockKind {
	var font: NSFont {
		switch self {
		case .paragraph:
			return NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
		case .heading(let level):
			switch level {
			case 1:
				return NSFont.monospacedSystemFont(ofSize: 24, weight: .bold)
			case 2:
				return NSFont.monospacedSystemFont(ofSize: 20, weight: .bold)
			case 3:
				return NSFont.monospacedSystemFont(ofSize: 16, weight: .bold)
			default:
				return NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
			}
		case .bullet, .ordered, .todo(_):
			return NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
		}
	}
}
