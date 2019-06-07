//
//  RollingView.swift
//  Messenger
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


protocol RollingViewDelegate {
	func rollingView(_ rollingView: RollingView, cellLayerForIndex: Int) -> CALayer
}



private class TiledLayer: CATiledLayer {
	override class func fadeDuration() -> CFTimeInterval {
		return 0
	}
}



private let CONTENT_HEIGHT: CGFloat = 10_000_000 // this is approximate; will be rounded to the nearest tile edge at run time


private class RollingContentView: UIView {

	enum Edge {
		case top
		case bottom
	}

	private var masterOffset: CGFloat = 0	// will become roughly CONTENT_HEIGHT / 2
	private var bgColor: UIColor?

	private var queue = DispatchQueue(label: "com.melikyan.RollingView")
	private var yCoordinates: [CGFloat] = []		// `y` coordinates of cells; negative values are allowed
	private var bottom: CGFloat = 0			// this is yCoordinates.last + the height of the last layer
	private var layerCache = CachingDictionary<NSNumber, CALayer>(capacity: 50) // to be replaced with a simpler implementation: we don't need thread safety, nor do we need costs


	convenience init(width: CGFloat, backgroundColor: UIColor?) {
		self.init()
		let tiledLayer = (layer as! TiledLayer)
		// Tiled layer's size is in device pixels but we don't translate it here because we want to get round numbers:
		masterOffset = floor(CONTENT_HEIGHT / tiledLayer.tileSize.height) * tiledLayer.tileSize.height
		frame = CGRect(x: 0, y: -masterOffset, width: width, height: masterOffset * 2)
		bgColor = backgroundColor
	}


	override class var layerClass: AnyClass {
		return TiledLayer.self
	}


	override func draw(_ layer: CALayer, in context: CGContext) {
		let box = context.boundingBoxOfClipPath
		if let bgColor = bgColor?.cgColor {
			context.setFillColor(bgColor)
			context.fill(box)
		}

		let tiledLayer = (layer as! TiledLayer)
		let tileSize = tiledLayer.tileSize
		let i = Int(box.origin.x * tiledLayer.contentsScale / tileSize.width)
		let j = Int((box.origin.y - masterOffset) * tiledLayer.contentsScale / tileSize.height)
		if j == 0 {
			print("Rendering", i, "main thread = ", Thread.isMainThread)
		}

		UIGraphicsPushContext(context)
		let font = UIFont(name: "CourierNewPS-BoldMT", size: 16)!
		let string = String(format: "%d, %d", i, j)
		let a = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: UIColor.lightGray])
		a.draw(at: CGPoint(x: box.origin.x + 1, y: box.origin.y + 1))
		UIGraphicsPopContext()
	}


	fileprivate func addLayers(to edge: Edge, layers: [CALayer]) {
		queue.async {
			switch edge {

			case .top:
				for layer in layers {
					let y = self.bottom
					layer.frame.origin.y = y
					self.yCoordinates.append(y)
					self.bottom += layer.frame.size.height
					self.layerCache[y as NSNumber] = layer
				}

			case .bottom:
				var newYCoordinates: [CGFloat] = []
				var y: CGFloat = self.yCoordinates.first ?? 0
				for layer in layers.reversed() {
					y -= layer.frame.size.height
					layer.frame.origin.y = y
					newYCoordinates.append(y)
					self.layerCache[y as NSNumber] = layer
				}
				self.yCoordinates.insert(contentsOf: newYCoordinates.reversed(), at: 0)
			}
		}
	}
}



class RollingView: UIScrollView {

	private var contentView: RollingContentView!
	private var firstLayout = true


	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}


	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setup()
	}


	private func setup() {
		contentView = RollingContentView(width: frame.size.width, backgroundColor: backgroundColor)
		contentView.autoresizingMask = .flexibleWidth
		insertSubview(contentView, at: 0)
		alwaysBounceVertical = true
	}


	override func layoutSubviews() {
		super.layoutSubviews()
		if firstLayout {
			firstLayout = false
			contentSize = bounds.size
		}
	}


	func addSpace(above height: CGFloat) {
		contentView.frame.origin.y += height
		contentSize.height += height
		contentOffset = CGPoint(x: contentOffset.x, y: contentOffset.y + height)
		contentView.layer.setNeedsDisplay(CGRect(x: 0, y: contentView.frame.origin.y - height, width: contentView.bounds.size.width, height: height))
	}
}
