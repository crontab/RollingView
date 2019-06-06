//
//  ViewController.swift
//  Messenger
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


class ViewController: UIViewController {


	@IBOutlet weak var rollingView: RollingView!


	override func viewDidLoad() {
		super.viewDidLoad()
		// let lines = resContents(name: "Text", ext: "txt")
	}


	@IBAction func addAction(_ sender: Any) {
		rollingView.addSpace(toTop: 256)
	}
}


private func resContents(name: String, ext: String) -> [String] {
	return try! String(contentsOfFile: Bundle.main.path(forResource: name, ofType: ext)!, encoding: .utf8).components(separatedBy: .newlines)
}
