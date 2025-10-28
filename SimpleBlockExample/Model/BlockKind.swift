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
			return NSFont.systemFont(ofSize: 14)
		case .heading(let level):
			switch level {
			case 1:
				return NSFont.boldSystemFont(ofSize: 24)
			case 2:
				return NSFont.boldSystemFont(ofSize: 20)
			case 3:
				return NSFont.boldSystemFont(ofSize: 16)
			default:
				return NSFont.boldSystemFont(ofSize: 14)
			}
		case .bullet, .ordered, .todo(_):
			return NSFont.systemFont(ofSize: 14)
		}
	}
}
