//
//  ConversationView.swift
//  Messenger
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


class TiledLayer: CATiledLayer {
	override class func fadeDuration() -> CFTimeInterval {
		return 0
	}
}


class ConversationContent: UIView {

	private var tiledLayer: TiledLayer!

	override class var layerClass: AnyClass {
		return TiledLayer.self
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		tiledLayer = (layer as! TiledLayer)
		tiledLayer.tileSize = CGSize(width: frame.size.width, height: 256)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func draw(_ layer: CALayer, in context: CGContext) {
		let box = context.boundingBoxOfClipPath

		let tileSize = tiledLayer.tileSize
		let x = box.origin.x * tiledLayer.contentsScale / tileSize.width
		let y = box.origin.y * tiledLayer.contentsScale / tileSize.height

		context.setFillColor(UIColor.lightGray.cgColor)
		context.fill(box.insetBy(dx: 0, dy: 0))

		UIGraphicsPushContext(context)
		let font = UIFont(name: "CourierNewPS-BoldMT", size: 16)!
		let string = String(format: "[%d, %d]", Int(x), Int(y))
		let a = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: UIColor.black])
		a.draw(at: CGPoint(x: box.origin.x + 1, y: box.origin.y + font.pointSize + 1))
		UIGraphicsPopContext()
	}
}


class ConversationView: UIScrollView {

	private var contentView: ConversationContent!

	override func awakeFromNib() {
		super.awakeFromNib()
		contentView = ConversationContent(frame: CGRect(x: 0, y: 0, width: bounds.size.width, height: 10000))
		contentView.backgroundColor = UIColor(white: 0.8, alpha: 1)
		contentView.autoresizingMask = .flexibleWidth
		insertSubview(contentView, at: 0)
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		contentSize = contentView.frame.size
	}

}
