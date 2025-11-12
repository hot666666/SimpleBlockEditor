//
//  BlockEditorViewController.swift
//  SimpleBlockExample
//
//  Created by hs on 2/9/26.
//

import AppKit
import Observation

/// 에디터 행을 스택으로 구성하고 편집 이벤트를 구독하는 상위 컨트롤러입니다.
final class BlockEditorViewController: NSViewController {
  private let manager: EditorBlockManager
  private var hasConfiguredInitialRows = false
  private var isObservingNodeEvents = false

  /// 에디터용 스크롤 뷰입니다.
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

  /// 상단을 기준으로 좌표가 증가하도록 만든 플립드 클립뷰입니다.
  private let clipView: FlippedClipView = {
    let cv = FlippedClipView()
    cv.translatesAutoresizingMaskIntoConstraints = false
    cv.drawsBackground = false
    return cv
  }()

  /// 행 뷰를 수직으로 배치하는 스택 뷰입니다.
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

  /// 행 컨트롤러 생애주기를 관리하는 코디네이터입니다.
  private lazy var rowCoordinator = BlockRowCoordinator(
		stackView: stackView,
		delegate: self
	)

  init(manager: EditorBlockManager) {
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
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    Task { @MainActor [weak self] in
      guard let self else { return }
      await self.manager.startStoreSync()
      self.configureInitialRowsIfNeeded()
      self.startObservingNodeEventsIfNeeded()
    }
  }

  override func viewWillDisappear() {
    super.viewWillDisappear()
		self.manager.stopStoreSync()
  }
}

extension BlockEditorViewController {
  fileprivate func configureInitialRowsIfNeeded() {
    guard !hasConfiguredInitialRows else { return }
    var seeds: [(Int, BlockNode)] = []
    manager.forEachInitialNode { seeds.append(($0, $1)) }
    rowCoordinator.bindInitialNodes(seeds)
    hasConfiguredInitialRows = true
  }

	/// Observable 기반 변화 감지
  fileprivate func startObservingNodeEventsIfNeeded() {
    guard !isObservingNodeEvents else { return }
    isObservingNodeEvents = true
    observeNodeEvents()
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

	/// 감지된 이벤트 모아서 처리
  fileprivate func drainNodeEvents() {
    let events = manager.observeNodeEvents()
    guard !events.isEmpty else { return }
    events.forEach(handleNodeEvent)
  }

	/// 이벤트 처리
  fileprivate func handleNodeEvent(_ event: EditorBlockEvent) {
    switch event {
    case .insert(let node, let index):
      rowCoordinator.insertRow(for: node, at: index)

    case .update(let node, let index):
      rowCoordinator.updateRow(for: node, index: index)

    case .remove(let node, _):
      rowCoordinator.removeRow(id: node.id)

    case .move(let node, _, let to):
      rowCoordinator.moveRow(id: node.id, to: to)

    case .focus(let change):
      handleFocusChange(change)
    }
  }

  fileprivate func handleFocusChange(_ change: EditorFocusEvent) {
    switch change {
    case .otherNode(let id, let caret):
      rowCoordinator.focusRow(id: id, caret: caret)
    case .clear:
      view.window?.makeFirstResponder(nil)
    }
  }
}

// MARK: - BlockRowCoordinatorDelegate

extension BlockEditorViewController: BlockRowCoordinatorDelegate {
  func blockRowCoordinator(_ coordinator: BlockRowCoordinator, notifyUpdateOf node: BlockNode) {
    manager.update(node: node)
  }

  func blockRowCoordinator(_ coordinator: BlockRowCoordinator, requestFocusChange change: EditorFocusEvent) {
    manager.applyFocusChange(change)
  }

  func blockRowCoordinator(_ coordinator: BlockRowCoordinator, commandFor event: EditorKeyEvent, node: BlockNode) -> EditorCommand? {
    manager.command(for: event, node: node)
  }
}
