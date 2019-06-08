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



struct CachingDictionary<K: AnyObject, T: AnyObject> {
	// Should be replaced with a simpler, non-thread-safe implementation

	private var cache = NSCache<K, T>()

	init(capacity: Int) {
		cache.countLimit = capacity
	}

	subscript(key: K) -> T? {
		get {
			return cache.object(forKey: key)
		}
		set {
			if newValue == nil {
				cache.removeObject(forKey: key)
			}
			else {
				cache.setObject(newValue!, forKey: key)
			}
		}
	}

	func clear() {
		cache.removeAllObjects()
	}
}
