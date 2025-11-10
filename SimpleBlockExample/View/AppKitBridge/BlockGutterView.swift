//
//  BlockGutterView.swift
//  SimpleBlockExample
//
//  Created by hs on 2/9/26.
//

import AppKit

final class BlockGutterView: NSView {
	private let bulletView = NSView(frame: .zero)
	private let orderedLabel = NSTextField(labelWithString: "")
	private let todoButton = NSButton(frame: .zero)
	private let contentContainer = NSView(frame: .zero)
	private var contentTopConstraint: NSLayoutConstraint!
	private var leadingConstraint: NSLayoutConstraint!
	private var widthConstraint: NSLayoutConstraint!

	var onToggle: ((Bool) -> Void)?

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

	func update(style: EditorStyle, kind: BlockKind, listNumber: Int?) {
		contentTopConstraint.constant = style.gutterPadding
		widthConstraint.constant = style.gutterSize.width

		switch kind {
		case .bullet:
			show(view: bulletView)
			isHidden = false
			leadingConstraint.constant = -style.gutterSpacing
		case .ordered:
			let number = max(listNumber ?? 1, 1)
			orderedLabel.stringValue = "\(number)."
			show(view: orderedLabel)
			isHidden = false
			leadingConstraint.constant = -style.gutterSpacing
		case .todo(let checked):
			todoButton.state = checked ? .on : .off
			show(view: todoButton)
			isHidden = false
			leadingConstraint.constant = -style.gutterSpacing
		default:
			show(view: nil)
			isHidden = true
			leadingConstraint.constant = -style.gutterSize.width - style.gutterSpacing
		}
	}
}

private extension BlockGutterView {
	func setUpViews() {
		addSubview(contentContainer)
		contentContainer.translatesAutoresizingMaskIntoConstraints = false

		contentTopConstraint = contentContainer.topAnchor.constraint(equalTo: topAnchor)
		leadingConstraint = contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor)
		widthConstraint = contentContainer.widthAnchor.constraint(equalToConstant: EditorStyle.Constants.gutterSize.width)

		NSLayoutConstraint.activate([
			contentTopConstraint,
			leadingConstraint,
			contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -EditorStyle.Constants.gutterSpacing),
			contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
			widthConstraint
		])

		setUpBullet()
		setUpOrdered()
		setUpTodo()
		show(view: nil)
	}

	func setUpBullet() {
		bulletView.wantsLayer = true
		bulletView.layer?.backgroundColor = NSColor.secondaryLabelColor.cgColor
		bulletView.layer?.cornerRadius = 3
		bulletView.translatesAutoresizingMaskIntoConstraints = false
		contentContainer.addSubview(bulletView)
		NSLayoutConstraint.activate([
			bulletView.widthAnchor.constraint(equalToConstant: 6),
			bulletView.heightAnchor.constraint(equalToConstant: 6),
			bulletView.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
			bulletView.centerYAnchor.constraint(equalTo: contentContainer.topAnchor, constant: EditorStyle.Constants.gutterSize.height / 2)
		])
	}

	func setUpOrdered() {
		orderedLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
		orderedLabel.textColor = .secondaryLabelColor
		orderedLabel.alignment = .center
		orderedLabel.translatesAutoresizingMaskIntoConstraints = false
		contentContainer.addSubview(orderedLabel)
		NSLayoutConstraint.activate([
			orderedLabel.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
			orderedLabel.centerYAnchor.constraint(equalTo: contentContainer.topAnchor, constant: EditorStyle.Constants.gutterSize.height / 2)
		])
	}

	func setUpTodo() {
		todoButton.title = ""
		todoButton.setButtonType(.switch)
		todoButton.isBordered = false
		todoButton.target = self
		todoButton.action = #selector(handleToggle(_:))
		todoButton.translatesAutoresizingMaskIntoConstraints = false
		contentContainer.addSubview(todoButton)
		NSLayoutConstraint.activate([
			todoButton.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
			todoButton.centerYAnchor.constraint(equalTo: contentContainer.topAnchor, constant: EditorStyle.Constants.gutterSize.height / 2)
		])
	}

	@objc func handleToggle(_ sender: NSButton) {
		onToggle?(sender.state == .on)
	}

	func show(view visible: NSView?) {
		let views = [bulletView, orderedLabel, todoButton]
		for view in views {
			view.isHidden = view !== visible
		}
	}
}
