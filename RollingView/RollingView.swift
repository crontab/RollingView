//
//  RollingView.swift
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


class RollingContentView: UIView {

	override class var layerClass: AnyClass {
		return TiledLayer.self
	}

	override func draw(_ layer: CALayer, in context: CGContext) {
		let tiledLayer = (layer as! TiledLayer)
		let box = context.boundingBoxOfClipPath

		let tileSize = tiledLayer.tileSize
		let x = box.origin.x * tiledLayer.contentsScale / tileSize.width
		let y = box.origin.y * tiledLayer.contentsScale / tileSize.height

		context.setFillColor(UIColor.lightGray.cgColor)
		context.fill(box.insetBy(dx: 0, dy: 0))

		UIGraphicsPushContext(context)
		let font = UIFont(name: "CourierNewPS-BoldMT", size: 12)!
		let string = String(format: "[%d, %d]", Int(x), Int(y))
		let a = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: UIColor.black])
		a.draw(at: CGPoint(x: box.origin.x + 1, y: box.origin.y + font.pointSize + 1))
		UIGraphicsPopContext()
	}
}


class RollingView: UIScrollView, UIScrollViewDelegate {

	private var contentView: RollingContentView!
	private var ceiling: CGFloat = 0

	override func awakeFromNib() {
		super.awakeFromNib()
	}


	override func layoutSubviews() {
		super.layoutSubviews()
		if contentView == nil {
			setupContentView()
		}
	}


	private func setupContentView() {
		contentView = RollingContentView(frame: CGRect(x: 0, y: 0, width: bounds.size.width, height: 100_000_000))
		contentView.autoresizingMask = .flexibleWidth
		insertSubview(contentView, at: 0)
		contentSize = contentView.frame.size
		ceiling = contentView.frame.size.height / 2
		setContentOffset(CGPoint(x: 0, y: ceiling), animated: false)
		delegate = self
	}
}
