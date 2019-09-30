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



public extension String {

	func size(withFont font: UIFont) -> CGSize {
		return (self as NSString).size(withAttributes: [NSAttributedString.Key.font: font])
	}
}


public extension UIView {

	class var reuseId: String {
		return String(describing: self)
	}

	class func fromNib() -> Self {
		return UIViewController(nibName: reuseId, bundle: nil).view as! Self
	}
}
