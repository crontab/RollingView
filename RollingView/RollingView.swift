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
		let delta = min(addedHeight, contentView.contentHeight - bounds.height)

		switch edge {
		case .top:
			if delta > 0 {
				contentSize.height += delta
				contentOffset.y += delta
				contentView.frame.top += delta
			}

		case .bottom:
			// "Scroll in" the new message if at the bottom of the sheet or within 20 pixels from it
			let scrollerIsAtBottom = contentSize.height - contentOffset.y <= bounds.height + 20
			if delta > 0 {
				contentSize.height += delta
			}
			if scrollerIsAtBottom {
				UIView.transition(with: self, duration: 0.25, options: .curveEaseInOut, animations: {
					if delta < 0 {
						self.contentSize = self.bounds.size
						self.contentView.frame.top -= addedHeight
					}
					else if delta < addedHeight {
						self.contentView.frame.top -= addedHeight - delta
					}
					self.scrollRectToVisible(CGRect(x: 0, y: self.contentSize.height - 1, width: 1, height: 1), animated: false)
				})
			}
		}
	}
}



private let CONTENT_HEIGHT: CGFloat = 10_000_000
private let MASTER_OFFSET = CONTENT_HEIGHT / 2


private class RollingContentView: UIView {

	private struct Placeholder {
		var layer: CALayer? // can be discarded to save memory; this provides our caching mechanism essentially
		var top: CGFloat
		var height: CGFloat

		var bottom: CGFloat {
			return top + height
		}

		init(layer: CALayer) {
			self.layer = layer
			self.top = layer.frame.top
			self.height = layer.frame.height
		}
	}


	private var bgColor: UIColor?

	private var orderedLayers: [Placeholder] = []	// ordered by the `y` coordinate

	private var startIndex = 0
	private var endIndex = 0

	private var contentTop: CGFloat {
		return orderedLayers.first?.top ?? MASTER_OFFSET
	}

	private var contentBottom: CGFloat {
		return orderedLayers.last?.bottom ?? MASTER_OFFSET
	}

	fileprivate var contentHeight: CGFloat {
		return contentBottom - contentTop
	}


	convenience init(parentWindowSize: CGSize, backgroundColor: UIColor?) {
		self.init()
		frame = CGRect(x: 0, y: -MASTER_OFFSET + parentWindowSize.height, width: parentWindowSize.width, height: CONTENT_HEIGHT)
		bgColor = backgroundColor
	}


	private var hostView: RollingView {
		return superview as! RollingView
	}


	fileprivate func prefetchIfNeeded(withPirority edge: RollingView.Edge) {
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
			var newLayers: [Placeholder] = []
			var top: CGFloat = contentTop
			for layer in layers.reversed() {
				let layerHeight = layer.frame.height
				top -= layerHeight
				totalHeight += layerHeight
				layer.frame.top = top
				newLayers.append(Placeholder(layer: layer))
				self.layer.addSublayer(layer)
			}
			orderedLayers.insert(contentsOf: newLayers.reversed(), at: 0)

		case .bottom:
			precondition(startIndex == endIndex)
			self.endIndex += layers.count
			for layer in layers {
				let layerHeight = layer.frame.height
				totalHeight += layerHeight
				layer.frame.top = contentBottom
				orderedLayers.append(Placeholder(layer: layer))
				self.layer.addSublayer(layer)
			}
		}

		hostView.contentDidAddSpace(edge: edge, addedHeight: totalHeight)
	}
}
