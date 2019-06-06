//
//  RollingView.swift
//  Messenger
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


private let CONTENT_HEIGHT: CGFloat = 10_000_000 // this is approximate; rounded to the nearest tile edge at run time


class TiledLayer: CATiledLayer {
	override class func fadeDuration() -> CFTimeInterval {
		return 0
	}
}


class RollingContentView: UIView {

	private var masterOffset: CGFloat = 0


	convenience init(width: CGFloat) {
		self.init()
		let tiledLayer = (layer as! TiledLayer)
		masterOffset = floor(CONTENT_HEIGHT / tiledLayer.tileSize.height) * tiledLayer.tileSize.height
		frame = CGRect(x: 0, y: -masterOffset, width: width, height: masterOffset * 2)
	}


	override class var layerClass: AnyClass {
		return TiledLayer.self
	}


	override func draw(_ layer: CALayer, in context: CGContext) {
		let tiledLayer = (layer as! TiledLayer)
		let box = context.boundingBoxOfClipPath

		let tileSize = tiledLayer.tileSize
		let i = box.origin.x * tiledLayer.contentsScale / tileSize.width
		let j = (box.origin.y - masterOffset) * tiledLayer.contentsScale / tileSize.height

		context.setFillColor(UIColor(white: 0.9, alpha: 1).cgColor)
		context.fill(box.insetBy(dx: 1, dy: 1))

		UIGraphicsPushContext(context)
		let font = UIFont(name: "CourierNewPS-BoldMT", size: 16)!
		let string = String(format: "%d, %d", Int(i), Int(j))
		let a = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: UIColor.black])
		a.draw(at: CGPoint(x: box.origin.x + 1, y: box.origin.y + 1))
		UIGraphicsPopContext()
	}
}


class RollingView: UIScrollView, UIScrollViewDelegate {

	private var contentView: RollingContentView!


	override func layoutSubviews() {
		super.layoutSubviews()
		if contentView == nil {
			setupContentView()
		}
	}


	private func setupContentView() {
		precondition(contentView == nil)
		contentView = RollingContentView(width: frame.size.width)
		contentView.autoresizingMask = .flexibleWidth
		insertSubview(contentView, at: 0)
		contentSize = CGSize(width: frame.size.width, height: contentView.frame.origin.y + contentView.frame.size.height)
		delegate = self
	}


	func addSpace(toTop height: CGFloat) {
		contentView.frame.origin.y += height
		setContentOffset(CGPoint(x: contentOffset.x, y: contentOffset.y + height), animated: false)
	}


	func scrollViewDidScroll(_ scrollView: UIScrollView) {
	}
}
