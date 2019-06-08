//
//  MainViewController.swift
//  Messenger
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


class MainViewController: UIViewController {

	@IBOutlet weak var rollingView: RollingView!


	override func viewDidLoad() {
		super.viewDidLoad()
		// let lines = try! String(contentsOfFile: Bundle.main.path(forResource: "Text", ofType: "txt")!, encoding: .utf8).components(separatedBy: .newlines)
	}


	@IBAction func addAction(_ sender: Any) {
	}
}
