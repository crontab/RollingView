//
//  ChatBubble.swift
//  RollingView
//
//  Created by Hovik Melikyan on 30/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


private let BIG_CORNER: CGFloat = 20
private let SMALL_CORNER: CGFloat = 6

private let Y_MARGIN: CGFloat = 2
private let Y_INSET: CGFloat = 9


class ChatBubble: UIView {

	@IBOutlet private weak var bubbleView: UIView!
	@IBOutlet private weak var textLabel: UILabel!

	var text: String {
		get { return textLabel.text ?? "" }
		set {
			textLabel.text = newValue
			layoutIfNeeded()
			frame.size.height = max(BIG_CORNER, textLabel.frame.maxY + Y_INSET + Y_MARGIN)
		}
	}

	class func create() -> Self {
		return fromNib()
	}


	override func awakeFromNib() {
		super.awakeFromNib()
		bubbleView.layer.cornerRadius = BIG_CORNER
	}
}


extension UIView {

	class var reuseId: String {
		return String(describing: self)
	}

	class func fromNib() -> Self {
		return UIViewController(nibName: reuseId, bundle: nil).view as! Self
	}
}


class RightChatBubble: ChatBubble {
}


class LeftChatBubble: ChatBubble {
}
