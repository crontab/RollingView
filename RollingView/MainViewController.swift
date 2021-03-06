//
//  MainViewController.swift
//  Messenger
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


class HeaderView: UIView { }
class FooterView: UIView { }


class MainViewController: UIViewController, RollingViewDelegate {

	@IBOutlet weak var rollingView: RollingView!

	@IBOutlet weak var topBar: UIVisualEffectView!
	@IBOutlet weak var bottomBar: UIView!


	private var lines = try! String(contentsOfFile: Bundle.main.path(forResource: "Bukowski", ofType: "txt")!, encoding: .utf8).components(separatedBy: .newlines).filter { !$0.isEmpty }


	override func viewDidLoad() {
		super.viewDidLoad()

		rollingView.register(cellClass: LeftChatBubble.self, create: LeftChatBubble.create)
		rollingView.register(cellClass: RightChatBubble.self, create: RightChatBubble.create)

		rollingView.alwaysBounceVertical = true
		// rollingView.showsVerticalScrollIndicator = false
		rollingView.rollingViewDelegate = self
	}


	private var firstLayout = true

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		if firstLayout {
			firstLayout = false
			// rollingView.fixedCellHeight = 42
			rollingView.contentInset.top = topBar.frame.height - view.safeAreaInsets.top
			rollingView.contentInset.bottom = bottomBar.frame.height
			rollingView.headerView = HeaderView.fromNib()
			rollingView.footerView = FooterView.fromNib()
		}
	}


	private let factories = [LeftChatBubble.self, RightChatBubble.self]
	private var indexBounds = [0, 0] // this is just to keep the left/right bubble distribution


	private func factoryForEdge(_ edge: RollingView.Edge) -> ChatBubble.Type {
		indexBounds[edge.rawValue] += 1
		return factories[indexBounds[edge.rawValue] % 3 == 0 ? 0 : 1]
	}


	@IBAction func addAction(_ sender: UIButton) {
		let edge = RollingView.Edge(rawValue: sender.tag)!
		let isCloseToBottom = rollingView.isCloseToBottom
		let factory = factoryForEdge(edge)
		rollingView.addCells(edge: edge, cellClass: factory, count: 1)
		if edge == .bottom && isCloseToBottom {
			rollingView.scrollToBottom(animated: true)
		}
	}


	func rollingView(_ rollingView: RollingView, reuseCell: UIView, forIndex index: Int) {
		(reuseCell as! ChatBubble).text = "\(index). " + lines[abs(index) % lines.count]
//		if index == 0 {
//			reuseCell.frame.size.height = CGFloat(Int.random(in: 40...100))
//		}
	}


	func rollingView(_ rollingView: RollingView, reached edge: RollingView.Edge, completion: @escaping (_ hasMore: Bool) -> Void) {
		switch edge {
		case .top:
//			DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//				rollingView.addCells(edge: edge, cellClass: self.factoryForEdge(edge), count: 1)
//				completion(true)
//			}
			completion(false)
		case .bottom:
			rollingView.addCells(edge: edge, cellClass: factoryForEdge(edge), count: 1)
			completion(false)
		}
	}


	func rollingView(_ rollingView: RollingView, didSelectCell cell: UIView?, atIndex index: Int) {
		print(index, (cell as? ChatBubble)?.text ?? "<not in memory>")
	}


	private var kbShown = false

	@IBAction func insetAction(_ sender: Any) {
//		rollingView.insertCells(at: 0, cellClass: factoryForEdge(.top), count: 1, animated: true)
//		rollingView.replaceCell(at: 0, cellClass: LeftChatBubble.self, animated: true)
		kbShown = !kbShown
		UIView.animate(withDuration: 0.25) {
			self.rollingView.contentInset.bottom = self.bottomBar.frame.height + (self.kbShown ? 300 : 0)
			self.rollingView.scrollToBottom(animated: false)
		}
	}


	@IBAction func tapAction(_ sender: UITapGestureRecognizer) {
		let point = sender.location(in: rollingView)
		print(rollingView.cellIndexFromPoint(point) ?? 0)
	}
}
