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

private let BIG_X_MARGIN: CGFloat = 90
private let SMALL_X_MARGIN: CGFloat = 10
private let X_INSET: CGFloat = 15


class ChatBubble: RollingViewCell {

	@IBOutlet private weak var bubbleView: UIView!
	@IBOutlet private weak var textLabel: UILabel!

	var text: String {
		get { return textLabel.text ?? "" }
		set {
			textLabel.text = newValue
			resizeIfNeeded()
		}
	}

	class func create(width: CGFloat) -> Self {
		let bubble = fromNib()
		bubble.frame.size.width = width
		return bubble
	}


	override func awakeFromNib() {
		super.awakeFromNib()
		translatesAutoresizingMaskIntoConstraints = false
		bubbleView.layer.cornerRadius = BIG_CORNER
	}


	private func resizeIfNeeded() {
		// Restore original widths and positions
		bubbleView.frame.size.width = frame.width - SMALL_X_MARGIN * 2 - BIG_X_MARGIN
		textLabel.frame.size.width = bubbleView.frame.width - X_INSET * 2

		// Now calculate the new height
		let labelOldHeight = textLabel.frame.height
		textLabel.preferredMaxLayoutWidth = textLabel.frame.width
		textLabel.sizeToFit()
		let labelHeightDelta = textLabel.frame.height - labelOldHeight
		frame.size.height = max(BIG_CORNER, frame.size.height + labelHeightDelta)
	}
}


class RightChatBubble: ChatBubble {
}


class LeftChatBubble: ChatBubble {
}
