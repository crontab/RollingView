//
//  Utilities.swift
//  RollingView
//
//  Created by Hovik Melikyan on 07/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation



extension Array where Element: Comparable {

	func binarySearch(_ x: Element) -> Index {
		var low = 0
		var high = count
		while low != high {
			let mid = (low + high) / 2
			if self[mid] < x {
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
