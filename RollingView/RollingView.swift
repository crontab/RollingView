//
//  RollingView.swift
//  RollingView
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


protocol RollingViewDelegate: class {
	func rollingView(_ rollingView: RollingView, cellLayerForIndex index: Int) -> CALayer
	func rollingView(_ rollingView: RollingView, updateCellLayer layer: CALayer?, forIndex index: Int) -> CALayer
	func rollingViewCanAddMoreAbove(_ rollingView: RollingView) -> Bool
}



class RollingView: UIScrollView {

	enum Edge: Int {
		case top
		case bottom
	}


	weak var rollingViewDelegate: RollingViewDelegate?


	func addCells(_ edge: Edge, count: Int) {
		guard count > 0 else {
			loadingMore = false
			return
		}
		let startIndex = contentView.startIndexForEdge(edge, newLayerCount: count)
		let layers = (startIndex..<(startIndex + count)).map { (index) -> CALayer in
			return rollingViewDelegate?.rollingView(self, cellLayerForIndex: index) ?? CALayer()
		}
		contentView.addLayers(to: edge, startIndex: startIndex, layers: layers)
	}


	func refreshCell(atIndex index: Int) {
		if let newLayer = rollingViewDelegate?.rollingView(self, updateCellLayer: contentView.layerForIndex(index), forIndex: index) {
			contentView.replaceLayer(newLayer, atIndex: index)
		}
	}


	func layerFromPoint(_ point: CGPoint) -> CALayer? {
		return contentView.layerFromPoint(convert(point, to: contentView))
	}


	// Private/protected

	private var contentView: RollingContentView!
	private var firstLayout = true


	override func awakeFromNib() {
		super.awakeFromNib()
		contentView = RollingContentView(parentWindowWidth: frame.width, backgroundColor: backgroundColor)
		contentView.autoresizingMask = .flexibleWidth
		insertSubview(contentView, at: 0)
	}


	override func layoutSubviews() {
		super.layoutSubviews()
		layout()
	}


	private func layout() {
		if firstLayout {
			firstLayout = false
			contentSize.width = frame.width
			contentInset.top = safeBoundsHeight - contentInset.bottom
		}
	}


	private var safeBoundsHeight: CGFloat {
		return bounds.height - safeAreaInsets.bottom - safeAreaInsets.top
	}


	var bottomInset: CGFloat {
		get { return contentInset.bottom }
		set {
			layout()
			let oldValue = bottomInset
			contentInset.bottom = newValue
			contentOffset.y += max(0, newValue - oldValue)
			contentInset.top = max(topInset, safeBoundsHeight - contentSize.height - contentInset.bottom)
		}
	}


	var topInset: CGFloat = 0 {
		didSet {
			layout()
			contentInset.top = max(topInset, safeBoundsHeight - contentSize.height - contentInset.bottom - topInset)
		}
	}


	private var reachedEnd: Bool = false
	private var loadingMore: Bool = false {
		didSet {
			if loadingMore {
				contentView.refreshIndicator.startAnimating()
			}
			else {
				contentView.refreshIndicator.stopAnimating()
			}
		}
	}

	override var contentOffset: CGPoint {
		didSet {
			if !firstLayout && !reachedEnd && !loadingMore {
				let offset = contentOffset.y + contentInset.top + safeAreaInsets.top
				if offset < frame.height {
					loadingMore = true
					DispatchQueue.main.async(execute: tryLoadMore)
				}
			}
		}
	}


	private func tryLoadMore() {
		let result = rollingViewDelegate?.rollingViewCanAddMoreAbove(self) ?? false
		if !result {
			loadingMore = false
			reachedEnd = true
		}
	}


	fileprivate func contentDidAddSpace(edge: Edge, addedHeight: CGFloat) {
		layout()

		let distanceToBottom = contentSize.height + contentInset.bottom - (contentOffset.y + bounds.height)
		contentSize.height += addedHeight
		let delta = contentInset.top - addedHeight

		switch edge {
		case .top:
			contentInset.top = max(topInset, delta)
			contentOffset.y += max(0, -delta + topInset)
			contentView.frame.top += addedHeight

		case .bottom:
			if distanceToBottom < 20 {
				UIView.transition(with: self, duration: 0.25, options: .curveEaseInOut, animations: {
					self.contentInset.top = max(self.topInset, delta)
					self.scrollRectToVisible(CGRect(x: 0, y: self.contentSize.height - 1, width: 1, height: 1), animated: false)
				})
			}
		}

		loadingMore = false
	}
}



private let CONTENT_HEIGHT: CGFloat = 10_000_000
private let MASTER_OFFSET = CONTENT_HEIGHT / 2
private let REFRESH_INDICATOR_TOP_OFFSET: CGFloat = -28


private class RollingContentView: UIView {

	fileprivate struct Placeholder {
		var layer: CALayer? // can be discarded to save memory; this provides our caching mechanism essentially (not yet)
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


	fileprivate var refreshIndicator: UIActivityIndicatorView!

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


	convenience init(parentWindowWidth: CGFloat, backgroundColor: UIColor?) {
		self.init()
		frame = CGRect(x: 0, y: -MASTER_OFFSET, width: parentWindowWidth, height: CONTENT_HEIGHT)
		bgColor = backgroundColor

		let indicatorSide: CGFloat = 20
		refreshIndicator = UIActivityIndicatorView(frame: CGRect(x: (parentWindowWidth - indicatorSide) / 2, y: contentTop + REFRESH_INDICATOR_TOP_OFFSET, width: indicatorSide, height: indicatorSide))
		refreshIndicator.autoresizingMask = [.flexibleLeftMargin]
		refreshIndicator.style = .gray
		addSubview(refreshIndicator)
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

		refreshIndicator.frame.top = contentTop + REFRESH_INDICATOR_TOP_OFFSET
		hostView.contentDidAddSpace(edge: edge, addedHeight: totalHeight)
	}


	fileprivate func layerForIndex(_ index: Int) -> CALayer? {
		return orderedLayers[index].layer
	}


	fileprivate func replaceLayer(_ layer: CALayer, atIndex index: Int) {
		var placeholder = orderedLayers[index]
		layer.frame.top = placeholder.top
		placeholder.layer?.removeFromSuperlayer()
		placeholder.layer = layer
		self.layer.addSublayer(layer)
	}


	fileprivate func layerFromPoint(_ point: CGPoint) -> CALayer? {
		let index = orderedLayers.binarySearch(top: point.y) - 1
		if index >= 0 && index < orderedLayers.count, let layer = orderedLayers[index].layer, layer.frame.contains(point) {
			return layer
		}
		return nil
	}
}


private extension Array where Element == RollingContentView.Placeholder {
	func binarySearch(top: CGFloat) -> Index {
		var low = 0
		var high = count
		while low != high {
			let mid = (low + high) / 2
			if self[mid].top < top {
				low = mid + 1
			} else {
				high = mid
			}
		}
		return low
	}
}
