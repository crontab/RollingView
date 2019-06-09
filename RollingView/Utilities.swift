//
//  Utilities.swift
//  RollingView
//
//  Created by Hovik Melikyan on 07/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation
import UIKit


extension CGRect {

	@inlinable
	var left: CGFloat {
		get { return origin.x }
		set { origin.x = newValue }
	}

	@inlinable
	var top: CGFloat {
		get { return origin.y }
		set { origin.y = newValue }
	}

	@inlinable
	var width: CGFloat {
		get { return size.width }
		set { size.width = newValue }
	}

	@inlinable
	var height: CGFloat {
		get { return size.height }
		set { size.height = newValue }
	}

	@inlinable
	var bottom: CGFloat {
		get { return origin.y + size.height }
		set { size.height = newValue - origin.y }
	}

	@inlinable
	var right: CGFloat {
		get { return origin.x + size.width }
		set { size.width = newValue - origin.x }
	}
}



extension Array where Element: Comparable {

	func binarySearch(_ item: Element) -> Index {
		var low = 0
		var high = count
		while low != high {
			let mid = (low + high) / 2
			if self[mid] < item {
				low = mid + 1
			} else {
				high = mid
			}
		}
		return low
	}
}
