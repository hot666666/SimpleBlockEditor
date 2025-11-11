//
//  BlockEditorViewController.swift
//  SimpleBlockExample
//
//  Created by hs on 2/9/26.
//

import AppKit
import Observation

final class BlockEditorViewController: NSViewController {
  private let manager: BlockManager

  private let scrollView: NSScrollView = {
    let sv = NSScrollView()
    sv.drawsBackground = false
    sv.hasVerticalScroller = true
    sv.autohidesScrollers = true
    sv.verticalScrollElasticity = .allowed
    sv.horizontalScrollElasticity = .none
    sv.borderType = .noBorder
    sv.translatesAutoresizingMaskIntoConstraints = false
    return sv
  }()

  private let clipView: FlippedClipView = {
    let cv = FlippedClipView()
    cv.translatesAutoresizingMaskIntoConstraints = false
    cv.drawsBackground = false
    return cv
  }()

  private let stackView: NSStackView = {
    let sv = NSStackView()
    sv.orientation = .vertical
    sv.alignment = .leading
    sv.spacing = EditorStyle.Constants.gutterSpacing
    sv.translatesAutoresizingMaskIntoConstraints = false
    sv.setHuggingPriority(.required, for: .vertical)
    sv.setContentCompressionResistancePriority(.required, for: .vertical)
    return sv
  }()

  private var rowControllers: [UUID: BlockRowController] = [:]

  init(manager: BlockManager) {
    self.manager = manager
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    scrollView.contentView = clipView
    scrollView.documentView = stackView

    NSLayoutConstraint.activate([
      stackView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
      stackView.topAnchor.constraint(equalTo: clipView.topAnchor),
      stackView.widthAnchor.constraint(equalTo: clipView.widthAnchor),
      stackView.bottomAnchor.constraint(greaterThanOrEqualTo: clipView.bottomAnchor),
    ])

    view = scrollView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    buildInitialRows()
    observeNodeEvents()
  }
}

// MARK: - Row creation & coordination

extension BlockEditorViewController {
  fileprivate func buildInitialRows() {
    manager.forEachInitialNode { index, node in
      insertRow(for: node, at: index)
    }
  }

  fileprivate func observeNodeEvents() {
    _ = withObservationTracking { [weak self] in
      self?.drainNodeEvents()
    } onChange: { [weak self] in
      /// 스택이 쌓이는 재귀 호출이 아니라, MainActor에 연쇄적인 비동기 작업 예약
      Task { @MainActor [weak self] in
        self?.observeNodeEvents()
      }
    }
  }

  fileprivate func drainNodeEvents() {
    let events = manager.observeNodeEvents()
    guard !events.isEmpty else { return }
    events.forEach(handleNodeEvent)
  }

  fileprivate func handleNodeEvent(_ event: BlockNodeEvent) {
    switch event {
    case .insert(let node, let index):
      insertRow(for: node, at: index)

    case .update(let node, let index):
      updateRow(for: node, index: index)

    case .remove(let node, _):
      removeRow(id: node.id)

    case .move(let node, let from, let to):
      moveRow(id: node.id, from: from, to: to)

    case .focus(let change):
      handleFocusChange(change)
    }
  }

  fileprivate func makeRowController(for node: BlockNode) -> BlockRowController {
    BlockRowController(node: node, delegate: self)
  }

  fileprivate func rowController(for node: BlockNode) -> BlockRowController {
    if let controller = rowControllers[node.id] {
      return controller
    }
    let controller = makeRowController(for: node)
    rowControllers[node.id] = controller
    return controller
  }

  fileprivate func insertRow(for node: BlockNode, at index: Int) {
    let controller = rowController(for: node)
    controller.bind(node: node)
    insertRowView(controller.view, at: index)
  }

  fileprivate func updateRow(for node: BlockNode, index: Int) {
    let controller = rowController(for: node)
    controller.bind(node: node)
    guard stackView.arrangedSubviews.contains(where: { $0 === controller.view }) else {
      insertRowView(controller.view, at: index)
      return
    }
  }

  fileprivate func moveRow(id: UUID, from _: Int, to: Int) {
    guard let controller = rowControllers[id] else { return }
    let view = controller.view
    guard let currentIndex = stackView.arrangedSubviews.firstIndex(where: { $0 === view }) else {
      insertRowView(view, at: to)
      return
    }
    guard currentIndex != to else { return }
    stackView.removeArrangedSubview(view)
    view.removeFromSuperview()
    insertRowView(view, at: to)
  }

  fileprivate func insertRowView(_ view: NSView, at index: Int) {
    let clamped = max(0, min(index, stackView.arrangedSubviews.count))
    if stackView.arrangedSubviews.contains(where: { $0 === view }) {
      stackView.removeArrangedSubview(view)
    }
    view.removeFromSuperview()
    stackView.insertArrangedSubview(view, at: clamped)
  }

  fileprivate func removeRow(id: UUID) {
    guard let controller = rowControllers.removeValue(forKey: id) else { return }
    let view = controller.view
    if stackView.arrangedSubviews.contains(where: { $0 === view }) {
      stackView.removeArrangedSubview(view)
    }
    view.removeFromSuperview()
    controller.teardown()
  }

  fileprivate func handleFocusChange(_ change: FocusChange) {
    switch change {
    case .otherNode(let id, let caret):
      focusRow(id: id, caret: caret)
    case .clear:
      view.window?.makeFirstResponder(nil)
    }
  }

  fileprivate func notifyUpdate(of node: BlockNode) {
    manager.notifyUpdate(of: node)
  }

  fileprivate func applyFocusChange(_ change: FocusChange, source _: BlockRowController?) {
    manager.applyFocusChange(change)
  }

  fileprivate func focusRow(id: UUID, caret: Int) {
    guard let target = rowControllers[id] else { return }
    target.focus(caret: caret)
  }

  fileprivate func command(for event: EditorEvent, node: BlockNode) -> EditCommand? {
    manager.editCommand(for: event, node: node)
  }
}

// MARK: - BlockRowControllerDelegate

extension BlockEditorViewController: BlockRowControllerDelegate {
  func rowController(_ controller: BlockRowController, notifyUpdateOf node: BlockNode) {
    notifyUpdate(of: node)
  }

  func rowController(_ controller: BlockRowController, requestFocusChange change: FocusChange) {
    applyFocusChange(change, source: controller)
  }

  func rowController(
    _ controller: BlockRowController, commandFor event: EditorEvent, node: BlockNode
  ) -> EditCommand? {
    command(for: event, node: node)
  }
}
