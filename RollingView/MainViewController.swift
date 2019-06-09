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


	private let leftFactory = TextBubbleFactory()
	private let rightFactory = TextBubbleFactory()

	private var lines = try! String(contentsOfFile: Bundle.main.path(forResource: "Bukowski", ofType: "txt")!, encoding: .utf8).components(separatedBy: .newlines)


	override func viewDidLoad() {
		super.viewDidLoad()
		rollingView.rollingViewDelegate = self

		leftFactory.font = UIFont.systemFont(ofSize: 17, weight: .regular)
		leftFactory.textColor = UIColor.white
		leftFactory.margins.right = 100
		leftFactory.bubbleColor = UIColor(red: 50 / 255, green: 135 / 255, blue: 255 / 255, alpha: 1)

		rightFactory.font = leftFactory.font
		rightFactory.textColor = UIColor.black
//		rightFactory.textAlignment = .right
		rightFactory.bubbleSide = .right
		rightFactory.margins.left = leftFactory.margins.right
		rightFactory.bubbleColor = UIColor(red: 231 / 255, green: 231 / 255, blue: 231 / 255, alpha: 1)
	}


	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		let s1 = "I used to hold my social security card up in the air, he told me, but I was so small they couldn't see it, all those big guys around."
		let layer1 = leftFactory.create(width: view.frame.width, text: s1)
		layer1.frame.top = 100
		view.layer.addSublayer(layer1)

		let s2 = "Yeah. well anyhow, I finally got on the other day picking tomatoes"
		let layer2 = rightFactory.create(width: view.frame.width, text: s2)
		layer2.frame.top = layer1.frame.bottom
		view.layer.addSublayer(layer2)
	}


	@IBAction func addAction(_ sender: UIButton) {
		let edge = RollingView.Edge(rawValue: sender.tag)!
		rollingView.addCells(edge, count: 1)
	}

//	private var lastSide: MessageBubbleView.Side = .right

	func rollingView(_ rollingView: RollingView, cellLayerForIndex index: Int) -> CALayer {
//		lastSide = lastSide.flipped
//		let text = lines[abs(index) % lines.count]
//		return instantiateBubble(side: lastSide, text: text)
		return CALayer()
	}
}
