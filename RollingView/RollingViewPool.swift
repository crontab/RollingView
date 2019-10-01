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
	func reuseCell(_ reuseCell: RollingViewCell, forIndex index: Int)
}


internal class RollingViewPool {

	internal func register(cellClass: RollingViewCell.Type, create: @escaping () -> RollingViewCell) {
		let key = ObjectIdentifier(cellClass)
		precondition(dict[key] == nil, "RollingViewCell class already registered")
		dict[key] = Pool(create: create)
	}


	internal func enqueue(_ element: RollingViewCell) {
		let key = ObjectIdentifier(type(of: element))
		precondition(dict[key] != nil, "RollingViewCell class not registered")
		RLOG("RollingView: recycling cell, recyclePool: \(count)")
		dict[key]!.array.append(element)
	}


	internal func dequeue(forIndex index: Int, cellClass: RollingViewCell.Type, width: CGFloat) -> RollingViewCell {
		let key = ObjectIdentifier(cellClass)
		precondition(dict[key] != nil, "RollingViewCell class not registered")
		var reuseCell: RollingViewCell
		if !dict[key]!.array.isEmpty {
			RLOG("RollingView: reusing cell at \(index), recyclePool: \(count)")
			reuseCell = dict[key]!.array.removeLast()
		}
		else {
			reuseCell = dict[key]!.create()
			RLOG("RellingView: ALLOC")
		}
		reuseCell.frame.size.width = width
		delegate!.reuseCell(reuseCell, forIndex: index)
		return reuseCell
	}


	internal var count: Int { dict.values.reduce(0) { $0 + $1.array.count } } // for debug printing only

	internal weak var delegate: RollingViewPoolProtocol?


	private struct Pool {
		var array: [RollingViewCell] = []
		var create: () -> RollingViewCell

		init (create: @escaping () -> RollingViewCell) {
			self.create = create
		}
	}


	private var dict: [ObjectIdentifier: Pool] = [:]
}
