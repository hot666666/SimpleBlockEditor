//
//  BlockRowCoordinator.swift
//  SimpleBlockEditor
//
//  Created by hs on 2/10/26.
//

import AppKit

// MARK: - BlockRowCoordinatorDelegate

/// Row 코디네이터가 상위 편집기에게 알림을 전달할 때 사용하는 델리게이트입니다.
protocol BlockRowCoordinatorDelegate: AnyObject {
  func blockRowCoordinator(_ coordinator: BlockRowCoordinator, notifyUpdateOf node: BlockNode)
  func blockRowCoordinator(_ coordinator: BlockRowCoordinator, requestFocusChange change: EditorFocusEvent)
  func blockRowCoordinator(_ coordinator: BlockRowCoordinator, commandFor event: EditorKeyEvent, node: BlockNode) -> EditorCommand?
}

// MARK: - BlockRowCoordinator

/// StackView 기반으로 BlockRowController 생애 주기를 관리하는 코디네이터입니다.
final class BlockRowCoordinator: NSObject {
  private weak var delegate: BlockRowCoordinatorDelegate?
  private let stackView: NSStackView
  private var controllers: [UUID: BlockRowController] = [:]

  init(stackView: NSStackView, delegate: BlockRowCoordinatorDelegate) {
    self.stackView = stackView
    self.delegate = delegate
    super.init()
  }

  /// 초기 노드 배열을 정렬 후 스택뷰에 삽입합니다.
  func bindInitialNodes(_ nodes: [(index: Int, node: BlockNode)]) {
    nodes.sorted(by: { $0.index < $1.index }).forEach { insertRow(for: $0.node, at: $0.index) }
  }

  /// 지정 인덱스에 행 컨트롤러와 뷰를 삽입합니다.
  func insertRow(for node: BlockNode, at index: Int) {
    let controller = controller(for: node)
    controller.bind(node: node)
    insertView(controller.view, at: index)
  }

  /// 기존 행의 노드 데이터를 갱신하거나 존재하지 않으면 삽입합니다.
  func updateRow(for node: BlockNode, index: Int) {
    let controller = controller(for: node)
    controller.bind(node: node)
    guard stackView.arrangedSubviews.contains(where: { $0 === controller.view }) else {
      insertView(controller.view, at: index)
      return
    }
  }

  /// 특정 행을 목적 인덱스로 이동합니다.
  func moveRow(id: UUID, to index: Int) {
    guard let controller = controllers[id] else { return }
    let view = controller.view
    guard let currentIndex = stackView.arrangedSubviews.firstIndex(where: { $0 === view }) else {
      insertView(view, at: index)
      return
    }
    guard currentIndex != index else { return }
    stackView.removeArrangedSubview(view)
    view.removeFromSuperview()
    insertView(view, at: index)
  }

  /// 행 컨트롤러와 뷰를 제거하고 teardown을 호출합니다.
  func removeRow(id: UUID) {
    guard let controller = controllers.removeValue(forKey: id) else { return }
    let view = controller.view
    if stackView.arrangedSubviews.contains(where: { $0 === view }) {
      stackView.removeArrangedSubview(view)
    }
    view.removeFromSuperview()
    controller.teardown()
  }

  /// 지정 행의 텍스트 뷰에 포커스를 부여합니다.
  func focusRow(id: UUID, caret: Int) {
    controllers[id]?.focus(caret: caret)
  }

  /// 모든 행 컨트롤러를 종료하고 컬렉션을 비웁니다.
  func teardownAll() {
    controllers.values.forEach { $0.teardown() }
    controllers.removeAll()
  }
}

private extension BlockRowCoordinator {
	/// BlockNode에 대한 컨트롤러 반환
	func controller(for node: BlockNode) -> BlockRowController {
		if let controller = controllers[node.id] {
			return controller
		}
		let controller = BlockRowController(node: node, delegate: self)
		controllers[node.id] = controller
		return controller
	}
	
	/// stackView에 뷰 삽입
	func insertView(_ view: NSView, at index: Int) {
		let clamped = max(0, min(index, stackView.arrangedSubviews.count))
		if stackView.arrangedSubviews.contains(where: { $0 === view }) {
			stackView.removeArrangedSubview(view)
		}
		view.removeFromSuperview()
		stackView.insertArrangedSubview(view, at: clamped)
	}
}

// MARK: - BlockRowControllerDelegate

extension BlockRowCoordinator: BlockRowControllerDelegate {
  func rowController(_ controller: BlockRowController, notifyUpdateOf node: BlockNode) {
    delegate?.blockRowCoordinator(self, notifyUpdateOf: node)
  }

  func rowController(_ controller: BlockRowController, requestFocusChange change: EditorFocusEvent) {
    delegate?.blockRowCoordinator(self, requestFocusChange: change)
  }

  func rowController(_ controller: BlockRowController, commandFor event: EditorKeyEvent, node: BlockNode) -> EditorCommand? {
    delegate?.blockRowCoordinator(self, commandFor: event, node: node)
  }
}
