//
//  TriggerMatch.swift
//  SimpleBlockExample
//
//  Created by hs on 10/28/25.
//

enum TriggerMatch {
	case heading(Int)   // 1...3
	case bullet         // -, *
	case todo(Bool)     // checked
}

@inline(__always)
func matchLeadingTriggerSpace(
	text: String,
	caretUTF16: Int
) -> (TriggerMatch, removeUTF16: Int)? {
	// 삭제 범위 = 트리거 길이 + 공백1(현재 입력)
	let remove = caretUTF16+1
	let u = text.utf16
	let n = u.count
	
	// 상수
	let SPACE: UInt16 = 32  // ' '
	let HASH: UInt16 = 35   // '#'
	let STAR: UInt16 = 42   // '*'
	let DASH: UInt16 = 45   // '-'
	let LBR: UInt16 = 91    // '['
	let RBR: UInt16 = 93    // ']'
	let X:   UInt16 = 120  // 'x'
	
	// bounds check는 케이스마다 guard로 보장
	@inline(__always)
	func c(_ off: Int) -> UInt16 {
		u[u.index(u.startIndex, offsetBy: off)]
	}
	
	switch caretUTF16 {
	case 1:
		guard n >= 1 else { return nil }
		let c0 = c(0)
		// "# "
		if c0 == HASH { return (.heading(1), remove) }
		// "- "
		if c0 == DASH { return (.bullet, remove) }
		// "* "
		if c0 == STAR { return (.bullet, remove) }
		return nil
		
	case 2:
		guard n >= 2 else { return nil }
		// "## "
		if c(0) == HASH, c(1) == HASH {
			return (.heading(2), remove)
		}
		return nil
		
	case 3:
		guard n >= 3 else { return nil }
		let c0 = c(0)
		let c1 = c(1)
		let c2 = c(2)
		// "### "
		if c0 == HASH, c1 == HASH, c2 == HASH {
			return (.heading(3), remove)
		}
		// "[ ] "
		if c0 == LBR, c1 == SPACE, c2 == RBR {
			return (.todo(false), remove)
		}
		// "[x] "
		if c0 == LBR, c1 == X, c2 == RBR {
			return (.todo(true), remove)
		}
		return nil
		
	default:
		return nil
	}
}
