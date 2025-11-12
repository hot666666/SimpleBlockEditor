//
//  BlockRowView.swift
//  SimpleBlockExample
//
//  Created by hs on 2/9/26.
//

import AppKit

final class BlockRowView: NSView {
  let textView: BlockTextView = {
    let tv = BlockTextView(frame: .zero)
    tv.isEditable = true
    tv.isRichText = false
    tv.drawsBackground = false
    tv.translatesAutoresizingMaskIntoConstraints = false
    tv.setContentHuggingPriority(.required, for: .vertical)
    tv.setContentCompressionResistancePriority(.required, for: .vertical)
    return tv
  }()
  private let gutterView = BlockGutterView()
  private var style = EditorStyle.style(for: .paragraph)
  private var gutterWidthConstraint: NSLayoutConstraint!
  private var textLeadingConstraint: NSLayoutConstraint!

  init() {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)

    setUpViews()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: NSSize {
    let textHeight = textView.intrinsicContentSize.height
    let height = max(textHeight, style.gutterSize.height)
    return NSSize(width: NSView.noIntrinsicMetric, height: height.isFinite ? height : 0)
  }

  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(textView)
    textView.mouseDown(with: event)
  }

  func apply(style: EditorStyle) {
    self.style = style
    style.apply(to: textView)
    updateLayout(for: style)
  }

  func updateGutter(kind: BlockKind, listNumber: Int?, style: EditorStyle) {
    gutterView.update(style: style, kind: kind, listNumber: listNumber)
    updateLayout(for: style)
  }

  func setTodoToggleHandler(_ handler: ((Bool) -> Void)?) {
    gutterView.onToggle = handler
  }
}

extension BlockRowView {
  fileprivate func setUpViews() {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(textView)

    addSubview(gutterView)
    addSubview(container)

    gutterWidthConstraint = gutterView.widthAnchor.constraint(
      equalToConstant: style.gutterSize.width)
    textLeadingConstraint = container.leadingAnchor.constraint(
      equalTo: gutterView.trailingAnchor, constant: style.gutterSpacing)

    NSLayoutConstraint.activate([
      gutterView.leadingAnchor.constraint(equalTo: leadingAnchor),
      gutterView.topAnchor.constraint(equalTo: topAnchor),
      gutterWidthConstraint,
      gutterView.bottomAnchor.constraint(equalTo: bottomAnchor),

      textLeadingConstraint,
      container.trailingAnchor.constraint(equalTo: trailingAnchor),
      container.topAnchor.constraint(equalTo: topAnchor),
      container.bottomAnchor.constraint(equalTo: bottomAnchor),

      textView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      textView.topAnchor.constraint(equalTo: container.topAnchor),
      textView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
  }

  fileprivate func updateLayout(for style: EditorStyle) {
    gutterWidthConstraint.constant = style.usesGutter ? style.gutterSize.width : 0
    textLeadingConstraint.constant = style.usesGutter ? style.gutterSpacing : 0
    gutterView.isHidden = !style.usesGutter
    invalidateIntrinsicContentSize()
  }
}
