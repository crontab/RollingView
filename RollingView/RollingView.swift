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
		let startIndex = contentView.startIndexForEdge(edge, newLayerCount: count)
		let layers = (startIndex..<(startIndex + count)).map { (index) -> CALayer in
			return rollingViewDelegate?.rollingView(self, cellLayerForIndex: index) ?? CALayer()
		}
		contentView.addLayers(to: edge, startIndex: startIndex, layers: layers)
	}


	// Private/protected

	private var contentView: RollingContentView!


	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}


	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setup()
	}


	private func setup() {
		alwaysBounceVertical = true
	}


	private var firstLayout = true

	override func layoutSubviews() {
		super.layoutSubviews()
		if firstLayout {
			firstLayout = false
			contentView = RollingContentView(parentWindowSize: bounds.size, backgroundColor: backgroundColor)
			contentView.autoresizingMask = .flexibleWidth
			insertSubview(contentView, at: 0)
			contentSize = bounds.size
		}
	}


	fileprivate func contentDidAddSpace(edge: Edge, addedHeight: CGFloat) {

		switch edge {
		case .top:
			let delta = min(addedHeight, contentView.totalContentHeight - bounds.height)
			if delta > 0 {
				contentSize.height += delta
				contentOffset.y += delta
				contentView.frame.top += delta
			}

		case .bottom:
			// "Scroll in" the new message if at the bottom of the sheet or within 20 pixels from it
			let scrollerIsAtBottom = contentSize.height - contentOffset.y <= bounds.height + 20
			contentSize.height += addedHeight
			if scrollerIsAtBottom {
				UIView.transition(with: self, duration: 0.25, options: .curveEaseInOut, animations: {
					if self.contentView.totalContentHeight < self.bounds.height {
						self.contentSize = self.bounds.size
						self.contentView.frame.top -= addedHeight
					}
					self.scrollRectToVisible(CGRect(x: 0, y: self.contentSize.height - 1, width: 1, height: 1), animated: false)
				})
			}
		}
	}
}



private let CONTENT_HEIGHT: CGFloat = 10_000_000
private let MASTER_OFFSET = CONTENT_HEIGHT / 2


private class RollingContentView: UIView, NSCacheDelegate {

	private var bgColor: UIColor?

	private var yCoordinates: [CGFloat] = []	// `y` coordinates of cells; negative values are allowed
	private var contentBottom: CGFloat = 0		// this is yCoordinates.last + the height of the last layer
	private var contentTop: CGFloat {
		return yCoordinates.first ?? contentBottom
	}

	private var layerCache = CachingDictionary<NSNumber, CALayer>(capacity: 50) // to be replaced with a simpler implementation: we don't need thread safety, nor do we need costs

	private var startIndex = 0
	private var endIndex = 0


	fileprivate var totalContentHeight: CGFloat {
		return contentBottom - contentTop
	}


	// CATiledLayer is very memory hungry even though it should be the opposite
	//	override class var layerClass: AnyClass {
	//		return CATiledLayer.self
	//	}


	convenience init(parentWindowSize: CGSize, backgroundColor: UIColor?) {
		self.init()
		layerCache.delegate = self
		contentBottom = MASTER_OFFSET
		frame = CGRect(x: 0, y: -MASTER_OFFSET + parentWindowSize.height, width: parentWindowSize.width, height: CONTENT_HEIGHT)
		bgColor = backgroundColor
	}


	private var hostView: RollingView {
		return superview as! RollingView
	}


	fileprivate func startIndexForEdge(_ edge: RollingView.Edge, newLayerCount count: Int) -> Int {
		switch edge {
		case .top:
			return startIndex - count
		case .bottom:
			return endIndex
		}
	}


	fileprivate func addLayers(to edge: RollingView.Edge, startIndex: Int, layers: [CALayer]) {
		var totalHeight: CGFloat = 0

		switch edge {

		case .top:
			precondition(startIndex + layers.count == self.startIndex)
			self.startIndex = startIndex
			var newYCoordinates: [CGFloat] = []
			var y: CGFloat = yCoordinates.first ?? MASTER_OFFSET
			for layer in layers.reversed() {
				let layerHeight = layer.frame.height
				y -= layerHeight
				totalHeight += layerHeight
				layer.frame.top = y
				layerCache[y as NSNumber] = layer
				newYCoordinates.append(y)
				self.layer.addSublayer(layer)
			}
			yCoordinates.insert(contentsOf: newYCoordinates.reversed(), at: 0)

		case .bottom:
			precondition(startIndex == endIndex)
			self.endIndex += layers.count
			for layer in layers {
				let layerHeight = layer.frame.height
				totalHeight += layerHeight
				layer.frame.top = contentBottom
				layerCache[contentBottom as NSNumber] = layer
				yCoordinates.append(contentBottom)
				contentBottom += layerHeight
				self.layer.addSublayer(layer)
			}
		}

		hostView.contentDidAddSpace(edge: edge, addedHeight: totalHeight)
	}


	func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
		(obj as! CALayer).removeFromSuperlayer()
	}
}
