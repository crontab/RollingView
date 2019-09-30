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

private let BIG_X_MARGIN: CGFloat = 100
private let SMALL_X_MARGIN: CGFloat = 10
private let STANDARD_MARGINS = UIEdgeInsets(top: 2, left: SMALL_X_MARGIN, bottom: 2, right: SMALL_X_MARGIN)
private let STANDARD_TEXT_INSETS = UIEdgeInsets(top: 9, left: 15, bottom: 9, right: 15)


class ChatBubble: UIView {

	@IBOutlet private weak var bubbleView: UIView!
	@IBOutlet private weak var textLabel: UILabel!

	var text: String {
		get { return textLabel.text ?? "" }
		set {
			textLabel.text = newValue
			resizeIfNeeded()
		}
	}


	class func create(width: CGFloat, text: String) -> Self {
		let bubble = fromNib()
		bubble.frame.size.width = width
		bubble.text = text
		return bubble
	}


	override func awakeFromNib() {
		super.awakeFromNib()
		translatesAutoresizingMaskIntoConstraints = false
		bubbleView.layer.cornerRadius = BIG_CORNER
	}


	private func resizeIfNeeded() {
		let labelOldHeight = textLabel.frame.height
		textLabel.preferredMaxLayoutWidth = textLabel.frame.width
		textLabel.sizeToFit()
		let labelHeightDelta = textLabel.frame.height - labelOldHeight
		if labelHeightDelta != 0 {
			frame.size.height = max(BIG_CORNER, frame.size.height + labelHeightDelta)
			setNeedsDisplay()
		}
	}
}


class RightChatBubble: ChatBubble {
}


class LeftChatBubble: ChatBubble {
}
