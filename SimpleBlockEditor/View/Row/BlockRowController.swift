//
//  BlockRowController.swift
//  SimpleBlockEditor
//
//  Created by hs on 11/10/25.
//

import AppKit

// MARK: - BlockRowControllerDelegate

/// 행 컨트롤러가 외부로 이벤트를 전달할 때 사용하는 델리게이트입니다.
protocol BlockRowControllerDelegate: AnyObject {
  func rowController(_ controller: BlockRowController, notifyUpdateOf node: BlockNode)
  func rowController(_ controller: BlockRowController, requestFocusChange change: EditorFocusEvent)
  func rowController(
    _ controller: BlockRowController, commandFor event: EditorKeyEvent, node: BlockNode
  ) -> EditorCommand?
}

// MARK: - BlockRowController

/// 단일 블록 행의 텍스트 입력·포커스·디바운스를 관리하는 컨트롤러입니다.
final class BlockRowController: NSObject {
  let view: BlockRowView

  weak var delegate: BlockRowControllerDelegate?

  private var node: BlockNode
  private let textView: BlockTextView
  private var isPendingUpdate = false
  private let debouncer = Debouncer()
  private let keyRouter = BlockRowInputRouter()
  private lazy var commandApplier = BlockRowCommandApplier(
    textView: textView,
    beforeFocusChange: { [weak self] in self?.flushPendingUpdate() },
    focusHandler: { [weak self] change in
      guard let self else { return }
      self.delegate?.rowController(self, requestFocusChange: change)
    }
  )

  init(node: BlockNode, delegate: BlockRowControllerDelegate) {
    self.node = node
    self.delegate = delegate
    self.view = BlockRowView()
    self.textView = view.textView
    super.init()

    configureTextView()
    view.setTodoToggleHandler { [weak self] checked in
      self?.handleTodoToggle(isChecked: checked)
    }
    bind(node: node)
  }

  func bind(node: BlockNode) {
    self.node = node

    let style = EditorStyle.style(for: node.kind, nodeStyle: node.style)
    view.apply(style: style)
    view.updateGutter(
      kind: node.kind,
      listNumber: node.listNumber,
      style: style
    )

    if textView.string != node.text {
      textView.string = node.text
    }
  }

  func focus(caret: Int) {
    let length = (textView.string as NSString).length
    let position = max(0, min(caret, length))
    textView.isEditable = true
    textView.setSelectedRange(NSRange(location: position, length: 0))
    textView.window?.makeFirstResponder(textView)
  }

  func teardown() {
    Task { await debouncer.cancel() }
  }
}

// MARK: - NSTextViewDelegate

extension BlockRowController: NSTextViewDelegate {
  func textDidChange(_ notification: Notification) {
    guard let tv = notification.object as? NSTextView, tv === textView else { return }
    node.text = tv.string
    scheduleUpdate()
  }
}

// MARK: - Private helpers

extension BlockRowController {
  fileprivate func configureTextView() {
    textView.delegate = self
    textView.string = node.text

    textView.keyEventHandler = { [weak self] event in
      guard let self else { return false }
      return self.handleKeyEvent(event)
    }

    textView.pointerDidFocusHandler = { [weak self] caret in
      guard let self else { return }
      self.delegate?.rowController(
        self, requestFocusChange: .otherNode(id: self.node.id, caret: caret))
    }

    textView.resignedFirstResponderHandler = { [weak self] shouldClear in
      guard let self else { return }
      self.flushPendingUpdate()
      if shouldClear {
        self.delegate?.rowController(self, requestFocusChange: .clear)
      }
    }
  }

  fileprivate func handleTodoToggle(isChecked: Bool) {
    node.kind = .todo(checked: isChecked)
    isPendingUpdate = false
    Task { await debouncer.cancel() }
    delegate?.rowController(self, notifyUpdateOf: node)
  }

  fileprivate func scheduleUpdate() {
    isPendingUpdate = true
    Task { [weak self] in
      guard let self else { return }
      await debouncer.updateScheduleOnMain(delay: .milliseconds(1500)) {
        guard self.isPendingUpdate else { return }
        self.isPendingUpdate = false
        self.delegate?.rowController(self, notifyUpdateOf: self.node)
      }
    }
  }

  fileprivate func flushPendingUpdate() {
    let shouldNotify = isPendingUpdate
    isPendingUpdate = false
    Task { await debouncer.cancel() }
    guard shouldNotify else { return }
    delegate?.rowController(self, notifyUpdateOf: node)
  }

  fileprivate func handleKeyEvent(_ event: NSEvent) -> Bool {
    guard let action = keyRouter.action(for: event, textView: textView) else {
      return false
    }

    switch action {
    case .softBreak:
      textView.insertLineBreak(nil)
      return true

    case .insertSpace(let info):
      textView.insertText(" ", replacementRange: info.selection)

      if let cmd = delegate?.rowController(self, commandFor: .spaceKey(info: info), node: node) {
        commandApplier.apply(cmd)
      }
      return true

    case .policy(let editorEvent):
      guard let cmd = delegate?.rowController(self, commandFor: editorEvent, node: node) else {
        return false
      }
      commandApplier.apply(cmd)
      return true
    }
  }
}
