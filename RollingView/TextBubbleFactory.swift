//
//  TextBubbleFactory.swift
//  RollingView
//
//  Created by Hovik Melikyan on 09/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


typealias StringAttributes = [NSAttributedString.Key: Any]

private let BIG_CORNER: CGFloat = 20
private let SMALL_CORNER: CGFloat = 6

private let BIG_X_MARGIN: CGFloat = 100
private let SMALL_X_MARGIN: CGFloat = 10
private let STANDARD_MARGINS = UIEdgeInsets(top: 2, left: SMALL_X_MARGIN, bottom: 2, right: SMALL_X_MARGIN)

private let CONTEXT_MASTER_INSETS = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)



class BubbleLayer: CALayer {
	var text: String

	init(text: String) {
		self.text = text
		super.init()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}


class LeftBubbleFactory: TextBubbleFactory {

	override init() {
		super.init()
		isRightSide = false
		font = UIFont.systemFont(ofSize: 16, weight: .medium)
		textColor = UIColor.black
		bubbleColor = UIColor(red:0.95, green:0.94, blue:0.94, alpha:1)
		margins.right = BIG_X_MARGIN
	}
}



class RightBubbleFactory: TextBubbleFactory {

	override init() {
		super.init()
		font = UIFont.systemFont(ofSize: 16, weight: .medium)
		textColor = UIColor.white
		bubbleColor = UIColor(red:0, green:0.53, blue:1, alpha:1)
		margins.left = BIG_X_MARGIN
	}
}



class TextBubbleFactory {

	fileprivate var isRightSide = true

	fileprivate var textAlignment: NSTextAlignment {
		get { return (attributes[.paragraphStyle] as! NSMutableParagraphStyle).alignment }
		set { (attributes[.paragraphStyle] as! NSMutableParagraphStyle).alignment = newValue }
	}

	fileprivate var font: UIFont? {
		get { return attributes[.font] as? UIFont }
		set { attributes[.font] = newValue }
	}

	fileprivate var textColor: UIColor? {
		get { return attributes[.foregroundColor] as? UIColor }
		set { attributes[.foregroundColor] = newValue }
	}

	fileprivate var insets = UIEdgeInsets(top: 9, left: 15, bottom: 9, right: 15)

	fileprivate var margins = STANDARD_MARGINS

	fileprivate var bubbleColor: UIColor? = UIColor(red: 50 / 255, green: 135 / 255, blue: 255 / 255, alpha: 1) // standard tint color
	fileprivate var backgroundColor = UIColor.white

	fileprivate var cornerRadius: CGFloat = BIG_CORNER


	private var attributes: StringAttributes = [.paragraphStyle: NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle]


	func create(width: CGFloat, string: String) -> BubbleLayer {
		let textLayer = TextLayer(maxWidth: width - insets.left - insets.right - margins.left - margins.right, string: string, attributes: attributes)
		textLayer.frame.left += insets.left
		textLayer.frame.top += insets.top

		let bubbleLayer = CALayer()
		bubbleLayer.frame.size = CGSize(width: textLayer.frame.right + insets.right, height: textLayer.frame.bottom + insets.bottom)
		bubbleLayer.backgroundColor = bubbleColor?.cgColor
		bubbleLayer.cornerRadius = min(cornerRadius, bubbleLayer.frame.height / 2)
		bubbleLayer.addSublayer(textLayer)
		bubbleLayer.frame.left += margins.left
		bubbleLayer.frame.top += margins.top
		if isRightSide {
			bubbleLayer.frame.left += width - margins.right - bubbleLayer.frame.right
		}

		let layer = BubbleLayer(text: string)
		layer.frame.size = CGSize(width: width, height: bubbleLayer.frame.bottom + margins.bottom)
		layer.backgroundColor = backgroundColor.cgColor
		layer.addSublayer(bubbleLayer)
		return layer
	}
}



private class TextLayer: CATextLayer {

	convenience init(maxWidth: CGFloat, string: String, attributes: StringAttributes) {
		self.init()
		self.contentsScale = UIScreen.main.scale
		let string = NSAttributedString(string: string, attributes: attributes)
		frame = string.boundingRect(with: CGSize(width: maxWidth, height: 10_000), options: [.usesFontLeading, .usesLineFragmentOrigin], context: nil)
		frame.size.width = ceil(frame.width)
		frame.size.height = ceil(frame.height)
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
