//
//  EditorStyle.swift
//  SimpleBlockExample
//
//  Created by hs on 11/8/25.
//

import AppKit

struct EditorStyle: Equatable {
  struct Constants {
    static let textInsets = NSSize(width: 0, height: 6)
    static let gutterSpacing: CGFloat = 2
    static let gutterSize: CGSize = {
      let baseFont = BlockNodeStyle(kind: .paragraph).makeAppKitFont()
      return CGSize(width: 18, height: baseFont.blockLineHeight)
    }()
  }

  var font: NSFont
  var textColor: NSColor
  var insertionPointColor: NSColor
  var textInsets: NSSize
  var gutterPadding: CGFloat
  var usesGutter: Bool
  var gutterSpacing: CGFloat
  var gutterSize: CGSize

  init(
    font: NSFont,
    textColor: NSColor = .labelColor,
    insertionPointColor: NSColor = .white,
    textInsets: NSSize = Constants.textInsets,
    gutterPadding: CGFloat = 0,
    usesGutter: Bool,
    gutterSpacing: CGFloat = Constants.gutterSpacing,
    gutterSize: CGSize = Constants.gutterSize
  ) {
    self.font = font
    self.textColor = textColor
    self.insertionPointColor = insertionPointColor
    self.textInsets = textInsets
    self.gutterPadding = gutterPadding
    self.usesGutter = usesGutter
    self.gutterSpacing = gutterSpacing
    self.gutterSize = gutterSize
  }

  static func style(for kind: BlockKind, nodeStyle: BlockNodeStyle? = nil) -> EditorStyle {
    let nodeStyle = nodeStyle ?? BlockNodeStyle(kind: kind)
    let font = nodeStyle.makeAppKitFont()
    let padding = kind.usesGutter ? Self.gutterPadding(for: font) : 0
    return EditorStyle(
      font: font,
      textColor: .labelColor,
      insertionPointColor: .white,
      textInsets: Constants.textInsets,
      gutterPadding: padding,
      usesGutter: kind.usesGutter,
      gutterSpacing: Constants.gutterSpacing,
      gutterSize: Constants.gutterSize
    )
  }

  private static func gutterPadding(for font: NSFont) -> CGFloat {
    let lineHeight = font.blockLineHeight
    let textCenter = Constants.textInsets.height + lineHeight / 2
    let gutterCenter = Constants.gutterSize.height / 2
    return max(textCenter - gutterCenter, 0)
  }

  func apply(to textView: NSTextView) {
    if textView.font?.isEqual(font) == false {
      textView.typingAttributes[.font] = font
      textView.textStorage?.beginEditing()
      if let storage = textView.textStorage {
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.removeAttribute(.font, range: fullRange)
        storage.addAttribute(.font, value: font, range: fullRange)
      }
      textView.textStorage?.endEditing()
      textView.font = font
    }

    if textView.textColor != textColor {
      textView.textColor = textColor
    }

    if textView.insertionPointColor != insertionPointColor {
      textView.insertionPointColor = insertionPointColor
    }

    if textView.textContainerInset != textInsets {
      textView.textContainerInset = textInsets
    }
  }
}
