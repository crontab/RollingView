//
//  MainViewController.swift
//  Messenger
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


class MainViewController: UIViewController, RollingViewDelegate {

	@IBOutlet weak var rollingView: RollingView!

	@IBOutlet weak var topBar: UIVisualEffectView!
	@IBOutlet weak var bottomBar: UIView!


	private let factories = [LeftChatBubble.self, RightChatBubble.self]

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
			rollingView.topInset = topBar.frame.height - view.safeAreaInsets.top + 16
			rollingView.bottomInset = bottomBar.frame.height + 16
			rollingView.addCells(.bottom, cellClass: LeftChatBubble.self, count: 1)
			indexBounds[RollingView.Edge.bottom.rawValue] += 1
		}
	}


	var indexBounds = [0, 0]

	@IBAction func addAction(_ sender: UIButton) {
		let edge = RollingView.Edge(rawValue: sender.tag)!
		var index = indexBounds[edge.rawValue]
		switch edge {
		case .top:
			index -= 1
		case .bottom:
			index += 1
		}
		indexBounds[edge.rawValue] = index
		let factory = factories[index % 3 == 0 ? 0 : 1]
		rollingView.addCells(edge, cellClass: factory, count: 1)
	}


	func rollingView(_ rollingView: RollingView, reuseCell: RollingViewCell, forIndex index: Int) {
		(reuseCell as! ChatBubble).text = "\(index). " + lines[abs(index) % lines.count]
	}


	func rollingViewCanAddCellsAbove(_ rollingView: RollingView, completion: @escaping (Bool) -> Void) {
//		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//			rollingView.addCells(.top, count: 2)
//			completion(true)
//		}
		completion(false)
	}


	private var kbShown = false

	@IBAction func insetAction(_ sender: Any) {
		kbShown = !kbShown
		UIView.animate(withDuration: 0.25) {
			self.rollingView.bottomInset = self.bottomBar.frame.height + (self.kbShown ? 300 : 0)
		}
	}


	@IBAction func tapAction(_ sender: UITapGestureRecognizer) {
		let point = sender.location(in: rollingView)
		print((rollingView.viewFromPoint(point) as? ChatBubble)?.text ?? "?")
	}

}
