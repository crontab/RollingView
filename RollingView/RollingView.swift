//
//  RollingView.swift
//  RollingView
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


protocol RollingViewDelegate: class {
	func rollingView(_ rollingView: RollingView, cellForIndex index: Int) -> UIView
	func rollingViewCanAddCellsAbove(_ rollingView: RollingView, completion: @escaping (_ tryAgain: Bool) -> Void)
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
		let startIndex = contentView.startIndexForEdge(edge, newViewCount: count)
		let views = (startIndex..<(startIndex + count)).map { (index) -> UIView in
			return rollingViewDelegate?.rollingView(self, cellForIndex: index) ?? UIView()
		}
		contentView.addViews(to: edge, startIndex: startIndex, views: views)
	}


	func viewFromPoint(_ point: CGPoint) -> UIView? {
		return contentView.viewFromPoint(convert(point, to: contentView))
	}


	// Private/protected

	private var contentView: RollingContentView!
	private var firstLayout = true


	override func awakeFromNib() {
		super.awakeFromNib()
		contentView = RollingContentView(parentWindowWidth: frame.width, backgroundColor: backgroundColor)
		contentView.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
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
		}
	}


	private var safeBoundsHeight: CGFloat {
		return bounds.height - safeAreaInsets.bottom - safeAreaInsets.top
	}


	var bottomInset: CGFloat {
		get { return contentInset.bottom }
		set {
			layout()
			contentInset.bottom = newValue
			self.scrollRectToVisible(CGRect(x: 0, y: self.contentSize.height - 1, width: 1, height: 1), animated: false)
		}
	}


	var topInset: CGFloat {
		get { return contentInset.top }
		set {
			layout()
			contentInset.top = newValue
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
		guard let rollingViewDelegate = rollingViewDelegate else {
			loadingMore = false
			reachedEnd = true
			return
		}
		rollingViewDelegate.rollingViewCanAddCellsAbove(self) { (tryAgain) in
			self.loadingMore = false
			self.reachedEnd = !tryAgain
		}
	}


	fileprivate func contentDidAddSpace(edge: Edge, addedHeight: CGFloat) {
		layout()

		let distanceToBottom = contentSize.height + contentInset.bottom - (contentOffset.y + bounds.height)
		contentSize.height += addedHeight

		switch edge {
		case .top:
			let delta = safeBoundsHeight - contentInset.top - contentInset.bottom - contentSize.height
			contentOffset.y += max(0, min(addedHeight, -delta))
			contentView.frame.top += addedHeight

		case .bottom:
			if distanceToBottom < 20 {
				UIView.transition(with: self, duration: 0.25, options: .curveEaseInOut, animations: {
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
		var cachedView: UIView? // can be discarded to save memory; this provides our caching mechanism essentially (not yet)
		var top: CGFloat
		var height: CGFloat

		var bottom: CGFloat {
			return top + height
		}

		init(view: UIView) {
			self.cachedView = view
			self.top = view.frame.top
			self.height = view.frame.height
		}
	}


	fileprivate var refreshIndicator: UIActivityIndicatorView!

	private var bgColor: UIColor?

	private var orderedViews: [Placeholder] = []	// ordered by the `y` coordinate

	private var startIndex = 0
	private var endIndex = 0


	private var contentTop: CGFloat {
		return orderedViews.first?.top ?? MASTER_OFFSET
	}


	private var contentBottom: CGFloat {
		return orderedViews.last?.bottom ?? MASTER_OFFSET
	}


	convenience init(parentWindowWidth: CGFloat, backgroundColor: UIColor?) {
		self.init()
		frame = CGRect(x: 0, y: -MASTER_OFFSET, width: parentWindowWidth, height: CONTENT_HEIGHT)
		bgColor = backgroundColor

		let indicatorSide: CGFloat = 20
		refreshIndicator = UIActivityIndicatorView(frame: CGRect(x: (parentWindowWidth - indicatorSide) / 2, y: contentTop + REFRESH_INDICATOR_TOP_OFFSET, width: indicatorSide, height: indicatorSide))
		refreshIndicator.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
		refreshIndicator.style = .gray
		addSubview(refreshIndicator)
	}


	private var hostView: RollingView {
		return superview as! RollingView
	}


	fileprivate func startIndexForEdge(_ edge: RollingView.Edge, newViewCount count: Int) -> Int {
		switch edge {
		case .top:
			return startIndex - count
		case .bottom:
			return endIndex
		}
	}


	fileprivate func addViews(to edge: RollingView.Edge, startIndex: Int, views: [UIView]) {
		var totalHeight: CGFloat = 0

		switch edge {

		case .top:
			precondition(startIndex + views.count == self.startIndex)
			self.startIndex = startIndex
			var newViews: [Placeholder] = []
			var top: CGFloat = contentTop
			for view in views.reversed() {
				let viewHeight = view.frame.height
				top -= viewHeight
				totalHeight += viewHeight
				view.frame.top = top
				newViews.append(Placeholder(view: view))
				self.addSubview(view)
			}
			orderedViews.insert(contentsOf: newViews.reversed(), at: 0)

		case .bottom:
			precondition(startIndex == endIndex)
			self.endIndex += views.count
			for view in views {
				let viewHeight = view.frame.height
				totalHeight += viewHeight
				view.frame.top = contentBottom
				orderedViews.append(Placeholder(view: view))
				self.addSubview(view)
			}
		}

		refreshIndicator.frame.top = contentTop + REFRESH_INDICATOR_TOP_OFFSET
		hostView.contentDidAddSpace(edge: edge, addedHeight: totalHeight)
	}


	fileprivate func viewFromPoint(_ point: CGPoint) -> UIView? {
		let index = orderedViews.binarySearch(top: point.y) - 1
		if index >= 0 && index < orderedViews.count, let view = orderedViews[index].cachedView, view.frame.contains(point) {
			return view
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
