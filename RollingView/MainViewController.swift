//
//  MainViewController.swift
//  Messenger
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


class MainViewController: UIViewController, RollingViewDelegate {

	@IBOutlet
	weak var rollingView: RollingView!


	private var lines = try! String(contentsOfFile: Bundle.main.path(forResource: "Bukowski", ofType: "txt")!, encoding: .utf8).components(separatedBy: .newlines)


	override func viewDidLoad() {
		super.viewDidLoad()
		rollingView.rollingViewDelegate = self
	}


	@IBAction func addAction(_ sender: UIButton) {
		let edge = RollingView.Edge(rawValue: sender.tag)!
		rollingView.addCells(edge, count: 2)
	}


	private func instantiateBubble(side: MessageBubbleView.Side, text: String) -> MessageBubbleView {
		let bubble = MessageBubbleView.loadFrom(storyboard: storyboard!, side: side)
		bubble.text = text
		bubble.frame.width = view.frame.width
		bubble.layoutIfNeeded()
		return bubble
	}


	private var lastSide: MessageBubbleView.Side = .right

	func rollingView(_ rollingView: RollingView, cellLayerForIndex index: Int) -> CALayer {
		lastSide = lastSide.flipped
		let text = lines[abs(index) % lines.count]
		return instantiateBubble(side: lastSide, text: text).layer
	}

}
