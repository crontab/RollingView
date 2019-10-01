//
//  RollingView.swift
//  RollingView
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


protocol RollingViewDelegate: class {
	func rollingView(_ rollingView: RollingView, cellForIndex index: Int, reuseView: RollingViewCell?) -> RollingViewCell
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
		let views = (startIndex..<(startIndex + count)).map { (index) -> RollingViewCell in
			return rollingViewDelegate?.rollingView(self, cellForIndex: index, reuseView: nil) ?? RollingViewCell()
		}
		let totalHeight = contentView.addCells(to: edge, cells: views)
		contentDidAddSpace(edge: edge, addedHeight: totalHeight)
	}


	func viewFromPoint(_ point: CGPoint) -> RollingViewCell? {
		return contentView.cellFromPoint(convert(point, to: contentView))
	}


	// Private/protected

	private var contentView: RollingViewContent!
	private var firstLayout = true


	override func awakeFromNib() {
		super.awakeFromNib()
		contentView = RollingViewContent(parentWindowWidth: frame.width)
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
				if offset < 0 /* frame.height */ {
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

