//
//  MainViewController.swift
//  Messenger
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


class MainViewController: UIViewController {

	@IBOutlet
	weak var rollingView: RollingView!


	override func viewDidLoad() {
		super.viewDidLoad()
		// let lines = try! String(contentsOfFile: Bundle.main.path(forResource: "Text", ofType: "txt")!, encoding: .utf8).components(separatedBy: .newlines)
		let left = MessageBubbleView.loadFrom(storyboard: storyboard!, id: "LeftBubble")
		left.frame.top = 100
		left.frame.width = view.frame.width
		left.text = "klj asdklja sdklj askldj aklsdja ksldjklas jdlkaj sdklajs dlkajs dklajs dlkajs dklasj dklajs dklajs d"
		view.addSubview(left)
		left.layoutIfNeeded()

		let right = MessageBubbleView.loadFrom(storyboard: storyboard!, id: "RightBubble")
		right.frame.top = left.frame.bottom
		right.frame.width = view.frame.width
		right.text = "Sane message. Not really kls jklaj sdklaj sdklaj sdkljasdkagf kjshd alksdakljs d"
		view.addSubview(right)
		right.layoutIfNeeded()
	}


	@IBAction func addAction(_ sender: Any) {
	}
}
