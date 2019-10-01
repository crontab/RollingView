//
//  RollingViewPool.swift
//  RollingView
//
//  Created by Hovik Melikyan on 01/10/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


typealias RollingViewCell = UIView


internal protocol RollingViewPoolProtocol: class {
	func cellForIndex(index: Int, reuseCell: RollingViewCell?) -> RollingViewCell
}


internal class RollingViewPool {

	internal func enqueue(_ element: RollingViewCell) {
		array.append(element)
	}

	internal func dequeue(forIndex index: Int) -> RollingViewCell {
		let reuseCell = !array.isEmpty ? array.removeLast() : nil
		let newCell = delegate!.cellForIndex(index: index, reuseCell: reuseCell)
		precondition(reuseCell == nil || newCell == reuseCell!) // ensure the provided cell is reused if available
		return newCell
	}

	internal var count: Int { array.count } // for debug printing only

	internal weak var delegate: RollingViewPoolProtocol?

	private var array: [RollingViewCell] = []
}
