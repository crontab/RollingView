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


	private let factories = [LeftBubbleFactory(), RightBubbleFactory()]
	private let contextFactory = ContextBubbleFactory()

	private var lines = try! String(contentsOfFile: Bundle.main.path(forResource: "Bukowski", ofType: "txt")!, encoding: .utf8).components(separatedBy: .newlines).filter { !$0.isEmpty }

	private var layerCount = 0


	override func viewDidLoad() {
		super.viewDidLoad()

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
			rollingView.addCells(.bottom, count: 1)
		}
	}


	@IBAction func addAction(_ sender: UIButton) {
		let edge = RollingView.Edge(rawValue: sender.tag)!
		rollingView.addCells(edge, count: 1)
	}


	func rollingView(_ rollingView: RollingView, cellLayerForIndex index: Int) -> CALayer {
		return self.rollingView(rollingView, updateCellLayer: nil, forIndex: index)
	}


	func rollingView(_ rollingView: RollingView, updateCellLayer layer: CALayer?, forIndex index: Int) -> CALayer {
		layerCount += 1
		if layerCount == 1 {
			let attr = VideoAttributes()
			attr.tags = ["tennis", "vegan"]
			attr.place = PlaceTag()
			attr.place!.name = "Ledru-Rollin"
			attr.time = TimeTag()
			return contextFactory.create(width: view.frame.width, isRightSide: true, title: "Maria contacted you because you set yourself available for:", attr: attr)
		}
		else {
			let factory = factories[Int.random(in: 0...1)]
			let string = lines[abs(index) % lines.count]
			return factory.create(width: view.frame.width, string: string)
		}
	}


	func rollingViewCanAddMoreAbove(_ rollingView: RollingView) -> Bool {
//		DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//			rollingView.addCells(.top, count: 20)
//		}
//		return true
		return false
	}


	private var kbShown = false

	@IBAction func insetAction(_ sender: Any) {
		kbShown = !kbShown
		UIView.animate(withDuration: 0.25) {
			self.rollingView.bottomInset = self.bottomBar.frame.height + (self.kbShown ? 300 : 0)
		}
	}
}
