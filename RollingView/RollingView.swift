//
//  RollingView.swift
//  Messenger
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


protocol RollingViewDelegate {
	func rollingView(_ rollingView: RollingView, cellLayerForIndex index: Int) -> CALayer
}



class RollingView: UIScrollView {

	enum Edge: Int {
		case top
		case bottom
	}


	var rollingViewDelegate: RollingViewDelegate?


	func addCells(_ edge: Edge, count: Int) {
		var start: Int
		switch edge {
		case .top:
			start = startIndex - count
			startIndex = start
		case .bottom:
			start = endIndex
			endIndex += count
		}
		let layers = (start..<(start + count)).map { (index) -> CALayer in
			let layer = rollingViewDelegate?.rollingView(self, cellLayerForIndex: index) ?? CALayer()
			return layer
		}
		contentView.addLayers(to: edge, layers: layers)
	}


	// Private/protected

	private var contentView: RollingContentView!
	private var firstLayout = true

	// This is redundant, but we keep it here so as not to bother with async access to RollingContentView's internal data
	private var startIndex = 0
	private var endIndex = 0


	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}


	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setup()
	}


	private func setup() {
		contentView = RollingContentView(width: frame.width, backgroundColor: backgroundColor)
		contentView.autoresizingMask = .flexibleWidth
		insertSubview(contentView, at: 0)
		alwaysBounceVertical = true
	}


	override func layoutSubviews() {
		super.layoutSubviews()
		if firstLayout {
			firstLayout = false
			contentSize = CGSize(width: bounds.width, height: 0)
		}
	}


	fileprivate func contentDidAddSpace(edge: Edge, height: CGFloat) {
		contentSize.height += height
		if edge == .top {
			if contentSize.height < bounds.height {
				// TODO:
				setContentOffset(CGPoint(x: 0, y: 0), animated: true)
			}
			else {
				contentOffset.y += height
			}
		}
	}
}



private let CONTENT_HEIGHT: CGFloat = 10_000_000 // this is approximate; will be rounded to the nearest tile edge at run time


private class RollingContentView: UIView {

	private class TiledLayer: CATiledLayer {
		override class func fadeDuration() -> CFTimeInterval {
			return 0
		}
	}


	private var masterOffset: CGFloat = 0		// will become roughly CONTENT_HEIGHT / 2
	private var bgColor: UIColor?

	private var queue = DispatchQueue(label: "com.melikyan.RollingView")
	private var yCoordinates: [CGFloat] = []	// `y` coordinates of cells; negative values are allowed
	private var bottom: CGFloat = 0				// this is yCoordinates.last + the height of the last layer
	private var layerCache = CachingDictionary<NSNumber, CALayer>(capacity: 50) // to be replaced with a simpler implementation: we don't need thread safety, nor do we need costs


	convenience init(width: CGFloat, backgroundColor: UIColor?) {
		self.init()
		let tiledLayer = (layer as! TiledLayer)
		// Tiled layer's size is in device pixels but we don't translate it here because we want to get round numbers:
		masterOffset = floor(CONTENT_HEIGHT / tiledLayer.tileSize.height) * tiledLayer.tileSize.height
		bottom = masterOffset
		frame = CGRect(x: 0, y: -masterOffset, width: width, height: masterOffset * 2)
		bgColor = backgroundColor
	}


	override class var layerClass: AnyClass {
		return TiledLayer.self
	}


	private var hostView: RollingView {
		return superview as! RollingView
	}


	fileprivate func addLayers(to edge: RollingView.Edge, layers: [CALayer]) {
		queue.async {
			var unionFrame: CGRect?

			switch edge {

			case .top:
				var newYCoordinates: [CGFloat] = []
				var y: CGFloat = self.yCoordinates.first ?? self.masterOffset
				for layer in layers.reversed() {
					let layerHeight = layer.frame.height
					y -= layerHeight
					layer.frame.top = y
					self.layerCache[y as NSNumber] = layer
					newYCoordinates.append(y)
					if let u = unionFrame {
						unionFrame = u.union(layer.frame)
					}
					else {
						unionFrame = layer.frame
					}
				}
				self.frame.top += (self.yCoordinates.first ?? self.masterOffset) - y
				self.yCoordinates.insert(contentsOf: newYCoordinates.reversed(), at: 0)

			case .bottom:
				for layer in layers {
					let layerHeight = layer.frame.height
					layer.frame.top = self.bottom
					self.layerCache[self.bottom as NSNumber] = layer
					self.yCoordinates.append(self.bottom)
					self.bottom += layerHeight
					if let u = unionFrame {
						unionFrame = u.union(layer.frame)
					}
					else {
						unionFrame = layer.frame
					}
				}
			}

			if let unionFrame = unionFrame {
				DispatchQueue.main.async {
					self.hostView.contentDidAddSpace(edge: edge, height: unionFrame.height)
					self.setNeedsDisplay(unionFrame)
				}
			}
		}
	}


	override func draw(_ layer: CALayer, in context: CGContext) {
		// let bgColor = (self.bgColor ?? UIColor.white).cgColor
		let box = context.boundingBoxOfClipPath

		context.translateBy(x: 0, y: CONTENT_HEIGHT)
		context.scaleBy(x: 1, y: -1)

		// TODO: fill empty spaces above and below layers with bgColor
		var index = yCoordinates.binarySearch(box.top)
		if index > 0 {
			index -= 1
		}
		if index < yCoordinates.count {
			let endY = min(bottom, box.top + box.height)
			var layerY = yCoordinates[index]
			while layerY < endY {
				if let layer = layerCache[layerY as NSNumber] {
					layer.render(in: context)
				}
				else {
					// TODO: fill with bgColor for now, then request a layer from delegate and invalidate the frame
				}
				index += 1
				layerY = index < yCoordinates.count ? yCoordinates[index] : endY
			}
		}

		#if DEBUG
			let tiledLayer = (layer as! TiledLayer)
			let tileSize = tiledLayer.tileSize
			let i = Int(box.left * tiledLayer.contentsScale / tileSize.width)
			let j = Int((box.top - masterOffset) * tiledLayer.contentsScale / tileSize.height)
			UIGraphicsPushContext(context)
			let font = UIFont(name: "CourierNewPS-BoldMT", size: 16)!
			let string = String(format: "%d, %d", i, j)
			let a = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: UIColor.lightGray])
			a.draw(at: CGPoint(x: box.left + 1, y: box.top + 1))
			UIGraphicsPopContext()
		#endif
	}
}
