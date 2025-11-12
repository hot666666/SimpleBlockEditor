//
//  BlockEditingPolicyImpl.swift
//  SimpleBlockExample
//
//  Created by hs on 2/5/26.
//

import Foundation

struct DefaultBlockEditingPolicy: BlockEditingPolicy {
  func makeEditorCommand(for event: EditorKeyEvent, node: BlockNode, in context: BlockEditingContext)
    -> EditorCommand?
  {
    switch event {
    case .spaceKey(let info):
      return handleSpace(info: info, node: node, context: context)

    case .returnKey(let info, let isTail):
      return handleEnter(info: info, isTail: isTail, node: node, context: context)

    case .shiftReturnKey:
      return nil

    case .backspaceAtStart:
      return handleDeleteAtStart(node: node, context: context)

    case .arrowUpKey(let info):
      return handleArrowUp(info: info, node: node, context: context)

    case .arrowDownKey(let info):
      return handleArrowDown(info: info, node: node, context: context)

    case .arrowLeftKey(let info):
      return handleArrowLeft(info: info, node: node, context: context)

    case .arrowRightKey(let info):
      return handleArrowRight(info: info, node: node, context: context)
    }
  }
}

extension DefaultBlockEditingPolicy {
  fileprivate func handleSpace(info: BlockCaretInfo, node: BlockNode, context: BlockEditingContext)
    -> EditorCommand?
  {
    guard let res = matchSpaceTrigger(text: node.text, caretUTF16: info.utf16) else {
      return nil
    }

    node.kind = res.kind
    context.notifyUpdate(of: node)

    return EditorCommand(removePrefixUTF16: res.removeUTF16, setCaretUTF16: 0)
  }

  fileprivate func handleEnter(
    info: BlockCaretInfo, isTail: Bool, node: BlockNode, context: BlockEditingContext
  ) -> EditorCommand? {
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

      return EditorCommand(requestFocusChange: .otherNode(id: newNode.id, caret: 0))
    } else {
      let newNode = BlockNode(kind: nextKind)
      context.insertNode(newNode, at: insertionIndex)

      return EditorCommand(requestFocusChange: .otherNode(id: newNode.id, caret: 0))
    }
  }

  fileprivate func handleDeleteAtStart(node: BlockNode, context: BlockEditingContext)
    -> EditorCommand?
  {
    if node.kind != .paragraph {
      node.kind = .paragraph
      context.notifyUpdate(of: node)
      return EditorCommand(setCaretUTF16: 0)
    }

    guard let index = context.index(of: node),
      let previous = context.previousNode(of: node)
    else { return nil }

    let caret = previous.text.count

    context.removeNode(at: index)
    previous.text += node.text
    context.notifyUpdate(of: previous)
    context.notifyMerge(from: node, into: previous)

    return EditorCommand(
      requestFocusChange: .otherNode(id: previous.id, caret: caret),
      insertText: node.text
    )
  }

  fileprivate func handleArrowUp(info: BlockCaretInfo, node: BlockNode, context: BlockEditingContext)
    -> EditorCommand?
  {
    guard let previous = context.previousNode(of: node) else { return nil }

    let previousUTF16 = (previous.text as NSString).length
    let newCaret: Int
    if previous.text.contains(where: \.isNewline) {
      newCaret = previousUTF16
    } else {
      newCaret = min(info.columnUTF16, previousUTF16)
    }

    return EditorCommand(requestFocusChange: .otherNode(id: previous.id, caret: newCaret))
  }

  fileprivate func handleArrowDown(info: BlockCaretInfo, node: BlockNode, context: BlockEditingContext)
    -> EditorCommand?
  {
    guard let next = context.nextNode(of: node) else { return nil }

    let nextUTF16 = (next.text as NSString).length
    let newCaret = min(info.columnUTF16, nextUTF16)

    return EditorCommand(requestFocusChange: .otherNode(id: next.id, caret: newCaret))
  }

  fileprivate func handleArrowLeft(info: BlockCaretInfo, node: BlockNode, context: BlockEditingContext)
    -> EditorCommand?
  {
    guard info.isAtStart, let previous = context.previousNode(of: node) else { return nil }

    let previousUTF16 = (previous.text as NSString).length
    return EditorCommand(requestFocusChange: .otherNode(id: previous.id, caret: previousUTF16))
  }

  fileprivate func handleArrowRight(info: BlockCaretInfo, node: BlockNode, context: BlockEditingContext)
    -> EditorCommand?
  {
    guard info.isAtTail, let next = context.nextNode(of: node) else { return nil }

    return EditorCommand(requestFocusChange: .otherNode(id: next.id, caret: 0))
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

    let utf16View = text.utf16
    let length = utf16View.count

    // bounds check는 케이스마다 guard로 보장
    func code(at offset: Int) -> UInt16 {
      utf16View[utf16View.index(utf16View.startIndex, offsetBy: offset)]
    }

    switch caretUTF16 {
    case 1:
      guard length >= 1 else { return nil }
      let code0 = code(at: 0)
      // "# "
      if code0 == UTF16Char.HASH {
        return SpaceTriggerMatch(kind: .heading(level: 1), removeUTF16: remove)
      }
      // "- " || "* "
      if code0 == UTF16Char.DASH || code0 == UTF16Char.STAR {
        return SpaceTriggerMatch(kind: .bullet, removeUTF16: remove)
      }
      return nil

    case 2:
      guard length >= 2 else { return nil }
      let code0 = code(at: 0)
      let code1 = code(at: 1)
      // "## "
      if code0 == UTF16Char.HASH && code1 == UTF16Char.HASH {
        return SpaceTriggerMatch(kind: .heading(level: 2), removeUTF16: remove)
      }
      // "[] "
      if code0 == UTF16Char.LBR && code1 == UTF16Char.RBR {
        return SpaceTriggerMatch(kind: .todo(checked: false), removeUTF16: remove)
      }
      return nil

    case 3:
      guard length >= 3 else { return nil }
      let code0 = code(at: 0)
      let code1 = code(at: 1)
      let code2 = code(at: 2)
      // "### "
      if code0 == UTF16Char.HASH && code1 == UTF16Char.HASH && code2 == UTF16Char.HASH {
        return SpaceTriggerMatch(kind: .heading(level: 3), removeUTF16: remove)
      }
      // "[ ] "
      if code0 == UTF16Char.LBR && code1 == UTF16Char.SPACE && code2 == UTF16Char.RBR {
        return SpaceTriggerMatch(kind: .todo(checked: false), removeUTF16: remove)
      }
      // "[x] "
      if code0 == UTF16Char.LBR && code1 == UTF16Char.lowercaseX && code2 == UTF16Char.RBR {
        return SpaceTriggerMatch(kind: .todo(checked: true), removeUTF16: remove)
      }
      return nil

    default:
      return nil
    }
  }
}

// MARK: - UTF16 Char Codes

private enum UTF16Char {
  static let SPACE: UInt16 = 32  // ' '
  static let HASH: UInt16 = 35  // '#'
  static let STAR: UInt16 = 42  // '*'
  static let DASH: UInt16 = 45  // '-'
  static let LBR: UInt16 = 91  // '['
  static let RBR: UInt16 = 93  // ']'
  static let lowercaseX: UInt16 = 120  // 'x'
}
