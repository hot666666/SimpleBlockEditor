//
//  BlockRowView.swift
//  SimpleBlockEditor
//
//  Created by hs on 2/9/26.
//

import AppKit

/// 텍스트 뷰와 거터를 묶어 행 레이아웃을 구성하는 컨테이너입니다.
final class BlockRowView: NSView {
	private var style = EditorStyle.style(for: .paragraph)
	private var gutterWidthConstraint: NSLayoutConstraint!
	private var textLeadingConstraint: NSLayoutConstraint!
	
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

  /// 텍스트 스타일을 적용하고 레이아웃을 최신화합니다.
  func apply(style: EditorStyle) {
    let needsIntrinsicUpdate = self.style.font != style.font

    self.style = style
    style.apply(to: textView)

    if needsIntrinsicUpdate {
      if let container = textView.textContainer {
        textView.layoutManager?.ensureLayout(for: container)
      }
      textView.invalidateIntrinsicContentSize()
    }

    updateLayout(for: style)
  }

  /// 블록 종류/번호 정보를 받아 거터 표시를 갱신합니다.
  func updateGutter(kind: BlockKind, listNumber: Int?, style: EditorStyle) {
    gutterView.update(style: style, kind: kind, listNumber: listNumber)
    updateLayout(for: style)
  }

  /// 할 일 토글 버튼 콜백을 외부에서 주입합니다.
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
