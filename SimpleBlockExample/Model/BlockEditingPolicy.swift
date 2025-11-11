//
//  BlockEditingPolicy.swift
//  SimpleBlockExample
//
//  Created by hs on 2/5/26.
//

import Foundation

protocol BlockEditingPolicy {
  func makeEditCommand(for event: EditorEvent, node: BlockNode, in context: BlockEditingContext)
    -> EditCommand?
}

// MARK: - DefaultBlockEditingPolicy

struct DefaultBlockEditingPolicy: BlockEditingPolicy {
  func makeEditCommand(for event: EditorEvent, node: BlockNode, in context: BlockEditingContext)
    -> EditCommand?
  {
    switch event {
    case .space(let info):
      return handleSpace(info: info, node: node, context: context)

    case .enter(let info, let isTail):
      return handleEnter(info: info, isTail: isTail, node: node, context: context)

    case .shiftEnter:
      return nil

    case .deleteAtStart:
      return handleDeleteAtStart(node: node, context: context)

    case .arrowUp(let info):
      return handleArrowUp(info: info, node: node, context: context)

    case .arrowDown(let info):
      return handleArrowDown(info: info, node: node, context: context)

    case .arrowLeft(let info):
      return handleArrowLeft(info: info, node: node, context: context)

    case .arrowRight(let info):
      return handleArrowRight(info: info, node: node, context: context)
    }
  }
}

// MARK: - Default handlers

extension DefaultBlockEditingPolicy {
  fileprivate func handleSpace(info: CaretInfo, node: BlockNode, context: BlockEditingContext)
    -> EditCommand?
  {
    guard let res = matchSpaceTrigger(text: node.text, caretUTF16: info.utf16) else {
      return nil
    }

    node.kind = res.kind
    context.notifyUpdate(of: node)

    return EditCommand(removePrefixUTF16: res.removeUTF16, setCaretUTF16: 0)
  }

  fileprivate func handleEnter(
    info: CaretInfo, isTail: Bool, node: BlockNode, context: BlockEditingContext
  ) -> EditCommand? {
    guard let index = context.index(of: node) else { return nil }

    let nextKind: BlockKind
    switch node.kind {
    case .bullet, .ordered, .todo(false):
      nextKind = node.kind
    case .todo(true):
      nextKind = .todo(checked: false)
    default:
      nextKind = .paragraph
    }

    let insertionIndex = index + 1

    if !isTail {
      let tail = node.text.cutSuffix(fromGrapheme: info.grapheme)
      context.notifyUpdate(of: node)

      let newNode = BlockNode(kind: nextKind, text: tail)
      context.insertNode(newNode, at: insertionIndex)

      return EditCommand(requestFocusChange: .otherNode(id: newNode.id, caret: 0))
    } else {
      let newNode = BlockNode(kind: nextKind)
      context.insertNode(newNode, at: insertionIndex)

      return EditCommand(requestFocusChange: .otherNode(id: newNode.id, caret: 0))
    }
  }

  fileprivate func handleDeleteAtStart(node: BlockNode, context: BlockEditingContext)
    -> EditCommand?
  {
    if node.kind != .paragraph {
      node.kind = .paragraph
      context.notifyUpdate(of: node)
      return EditCommand(setCaretUTF16: 0)
    }

    guard let index = context.index(of: node),
      let previous = context.previousNode(of: node)
    else { return nil }

    let caret = previous.text.count

    context.removeNode(at: index)
    previous.text += node.text
    context.notifyUpdate(of: previous)
    context.notifyMerge(from: node, into: previous)

    return EditCommand(
      requestFocusChange: .otherNode(id: previous.id, caret: caret),
      insertText: node.text
    )
  }

  fileprivate func handleArrowUp(info: CaretInfo, node: BlockNode, context: BlockEditingContext)
    -> EditCommand?
  {
    guard let previous = context.previousNode(of: node) else { return nil }

    let previousUTF16 = (previous.text as NSString).length
    let newCaret: Int
    if previous.text.contains(where: \.isNewline) {
      newCaret = previousUTF16
    } else {
      newCaret = min(info.columnUTF16, previousUTF16)
    }

    return EditCommand(requestFocusChange: .otherNode(id: previous.id, caret: newCaret))
  }

  fileprivate func handleArrowDown(info: CaretInfo, node: BlockNode, context: BlockEditingContext)
    -> EditCommand?
  {
    guard let next = context.nextNode(of: node) else { return nil }

    let nextUTF16 = (next.text as NSString).length
    let newCaret = min(info.columnUTF16, nextUTF16)

    return EditCommand(requestFocusChange: .otherNode(id: next.id, caret: newCaret))
  }

  fileprivate func handleArrowLeft(info: CaretInfo, node: BlockNode, context: BlockEditingContext)
    -> EditCommand?
  {
    guard info.isAtStart, let previous = context.previousNode(of: node) else { return nil }

    let previousUTF16 = (previous.text as NSString).length
    return EditCommand(requestFocusChange: .otherNode(id: previous.id, caret: previousUTF16))
  }

  fileprivate func handleArrowRight(info: CaretInfo, node: BlockNode, context: BlockEditingContext)
    -> EditCommand?
  {
    guard info.isAtTail, let next = context.nextNode(of: node) else { return nil }

    return EditCommand(requestFocusChange: .otherNode(id: next.id, caret: 0))
  }
}

// MARK: - Matching leading trigger space

extension DefaultBlockEditingPolicy {
  // 트리거 매칭 결과
  fileprivate struct SpaceTriggerMatch {
    let kind: BlockKind
    let removeUTF16: Int
  }

  // 공백 트리거 매칭
  fileprivate func matchSpaceTrigger(
    text: String,
    caretUTF16: Int
  ) -> SpaceTriggerMatch? {
    // 삭제 범위 = 트리거 길이 + 공백1(현재 입력)
    let remove = caretUTF16 + 1

    let u = text.utf16
    let n = u.count

    // bounds check는 케이스마다 guard로 보장
    func c(_ off: Int) -> UInt16 {
      u[u.index(u.startIndex, offsetBy: off)]
    }

    switch caretUTF16 {
    case 1:
      guard n >= 1 else { return nil }
      let c0 = c(0)
      // "# "
      if c0 == UTF16Char.HASH {
        return SpaceTriggerMatch(kind: .heading(level: 1), removeUTF16: remove)
      }
      // "- " || "* "
      if c0 == UTF16Char.DASH || c0 == UTF16Char.STAR {
        return SpaceTriggerMatch(kind: .bullet, removeUTF16: remove)
      }
      return nil

    case 2:
      guard n >= 2 else { return nil }
      let c0 = c(0)
      let c1 = c(1)
      // "## "
      if c0 == UTF16Char.HASH && c1 == UTF16Char.HASH {
        return SpaceTriggerMatch(kind: .heading(level: 2), removeUTF16: remove)
      }
      // "[] "
      if c0 == UTF16Char.LBR && c1 == UTF16Char.RBR {
        return SpaceTriggerMatch(kind: .todo(checked: false), removeUTF16: remove)
      }
      return nil

    case 3:
      guard n >= 3 else { return nil }
      let c0 = c(0)
      let c1 = c(1)
      let c2 = c(2)
      // "### "
      if c0 == UTF16Char.HASH && c1 == UTF16Char.HASH && c2 == UTF16Char.HASH {
        return SpaceTriggerMatch(kind: .heading(level: 3), removeUTF16: remove)
      }
      // "[ ] "
      if c0 == UTF16Char.LBR && c1 == UTF16Char.SPACE && c2 == UTF16Char.RBR {
        return SpaceTriggerMatch(kind: .todo(checked: false), removeUTF16: remove)
      }
      // "[x] "
      if c0 == UTF16Char.LBR && c1 == UTF16Char.X && c2 == UTF16Char.RBR {
        return SpaceTriggerMatch(kind: .todo(checked: true), removeUTF16: remove)
      }
      return nil

    default:
      return nil
    }
  }
}

// MARK: - UTF16 Char Codes

enum UTF16Char {
  static let SPACE: UInt16 = 32  // ' '
  static let HASH: UInt16 = 35  // '#'
  static let STAR: UInt16 = 42  // '*'
  static let DASH: UInt16 = 45  // '-'
  static let LBR: UInt16 = 91  // '['
  static let RBR: UInt16 = 93  // ']'
  static let X: UInt16 = 120  // 'x'
}
