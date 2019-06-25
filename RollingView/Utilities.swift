//
//  Utilities.swift
//  RollingView
//
//  Created by Hovik Melikyan on 07/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

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


extension Data {

	func toURLSafeBase64() -> String {
		return base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "_").replacingOccurrences(of: "=", with: "")
	}

	func toSHA256() -> Data {
		var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
		withUnsafeBytes {
			_ = CC_SHA256($0.baseAddress, CC_LONG(count), &hash)
		}
		return Data(hash)
	}
}



public extension String {

	func toSHA256() -> Data {
		return (data(using: .utf8) ?? Data()).toSHA256()
	}

	func toURLSafeHash(max: Int) -> String {
		return String(toSHA256().toURLSafeBase64().suffix(max))
	}

	func size(withFont font: UIFont) -> CGSize {
		return (self as NSString).size(withAttributes: [NSAttributedString.Key.font: font])
	}
}


public extension UIColor {

	var isDark: Bool {
		var white: CGFloat = 1
		var alpha: CGFloat = 1
		getWhite(&white, alpha: &alpha)
		return white < 0.8
	}
}


extension FileManager {

	class func cacheDirectory(subDirectory: String, create: Bool) -> String {
		guard var result = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else {
			preconditionFailure("No cache directory")
		}
		result += "/" + subDirectory
		if create && !`default`.fileExists(atPath: result) {
			do {
				try `default`.createDirectory(atPath: result, withIntermediateDirectories: true, attributes: nil)
			}
			catch {
				preconditionFailure("Couldn't create cache directory (\(result))")
			}
		}
		return result
	}
}
