//
//  TextBubbleLayer.swift
//  RollingView
//
//  Created by Hovik Melikyan on 09/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


typealias StringAttributes = [NSAttributedString.Key: Any]


class TextBubbleFactory {

	enum Side: Int {
		case left
		case right
	}

	var bubbleSide: Side = .left

	var textAlignment: NSTextAlignment {
		get { return (attributes[.paragraphStyle] as! NSMutableParagraphStyle).alignment }
		set { (attributes[.paragraphStyle] as! NSMutableParagraphStyle).alignment = newValue }
	}

	var font: UIFont? {
		get { return attributes[.font] as? UIFont }
		set { attributes[.font] = newValue }
	}

	var textColor: UIColor? {
		get { return attributes[.foregroundColor] as? UIColor }
		set { attributes[.foregroundColor] = newValue }
	}

	var insets = UIEdgeInsets(top: 6, left: 12, bottom: 8, right: 12)

	var margins = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)

	var bubbleColor: UIColor? = UIColor(red: 50 / 255, green: 135 / 255, blue: 255 / 255, alpha: 1) // standard tint color
	var backgroundColor = UIColor.white

	var cornerRadius: CGFloat = 8


	private var attributes: StringAttributes = [.paragraphStyle: NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle]


	func create(width: CGFloat, string: String) -> CALayer {
		let textLayer = TextLayer(maxWidth: width - insets.left - insets.right - margins.left - margins.right, string: string, attributes: attributes)
		textLayer.frame.left += insets.left
		textLayer.frame.top += insets.top

		let bubbleLayer = CALayer()
		bubbleLayer.frame.size = CGSize(width: textLayer.frame.right + insets.right, height: textLayer.frame.bottom + insets.bottom)
		bubbleLayer.backgroundColor = bubbleColor?.cgColor
		bubbleLayer.cornerRadius = cornerRadius
		bubbleLayer.addSublayer(textLayer)
		bubbleLayer.frame.left += margins.left
		bubbleLayer.frame.top += margins.top
		if bubbleSide == .right {
			bubbleLayer.frame.left += width - margins.right - bubbleLayer.frame.right
		}

		let layer = CALayer()
		layer.frame.size = CGSize(width: width, height: bubbleLayer.frame.bottom + margins.bottom)
		layer.backgroundColor = backgroundColor.cgColor
		layer.addSublayer(bubbleLayer)
		return layer
	}


	private class TextLayer: CATextLayer {

		convenience init(maxWidth: CGFloat, string: String, attributes: StringAttributes) {
			self.init()
			self.contentsScale = UIScreen.main.scale
			let string = NSAttributedString(string: string, attributes: attributes)
			frame = string.boundingRect(with: CGSize(width: maxWidth, height: 10_000), options: [.usesFontLeading, .usesLineFragmentOrigin], context: nil)
			self.isWrapped = true
			switch (attributes[.paragraphStyle] as? NSParagraphStyle)?.alignment ?? .left {
			case .left: 	self.alignmentMode = .left
			case .right:	self.alignmentMode = .right
			case .center:	self.alignmentMode = .center
			case .justified: self.alignmentMode = .justified
			case .natural:	self.alignmentMode = .natural
			@unknown default:
				break
			}
			self.string = string
		}
	}
}
