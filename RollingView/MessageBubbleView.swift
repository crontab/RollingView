//
//  MessageBubbleView.swift
//  RollingView
//
//  Created by Hovik Melikyan on 08/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


@IBDesignable
class MessageBubble: UIView {

	@IBInspectable
	var cornerRadius: CGFloat {
		get { return layer.cornerRadius }
		set { layer.cornerRadius = newValue }
	}
}


class MessageBubbleView: UIView {

	var text: String? {
		get { return textLabel.text }
		set {
			textLabel.text = newValue
			layoutIfNeeded()
		}
	}

	@IBOutlet
	private weak var textLabel: UILabel!

	@IBOutlet
	private weak var bubble: MessageBubble!


	class func loadFrom(storyboard: UIStoryboard, id: String) -> Self {
		// The absurdity that's Swift's type system. If something is possible to do with two functions, why not let it be just one?
		func loadFromImpl<T>() -> T {
			return storyboard.instantiateViewController(withIdentifier: id).view as! T
		}
		return loadFromImpl()
	}


	override func layoutSubviews() {
		super.layoutSubviews()
		adjustHeight()
	}


	private func adjustHeight() {
		let vertSpacing = bubble.frame.top
		frame.height = bubble.frame.bottom + vertSpacing
	}
}
