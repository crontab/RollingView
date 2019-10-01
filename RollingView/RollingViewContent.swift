//
//  RollingViewContent.swift
//  RollingView
//
//  Created by Hovik Melikyan on 01/10/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


private let CONTENT_HEIGHT: CGFloat = 10_000_000
private let MASTER_OFFSET = CONTENT_HEIGHT / 2
private let REFRESH_INDICATOR_TOP_OFFSET: CGFloat = -28



class RollingViewCell: UIView {
}



class RollingViewContent: UIView {

	fileprivate struct Placeholder {
		var cachedView: RollingViewCell? // can be discarded to save memory; this provides our caching mechanism essentially (not yet)
		var top: CGFloat
		var height: CGFloat

		var bottom: CGFloat {
			return top + height
		}

		init(view: RollingViewCell) {
			self.cachedView = view
			self.top = view.frame.top
			self.height = view.frame.height
		}
	}


	internal var refreshIndicator: UIActivityIndicatorView!

	private var orderedCells: [Placeholder] = []	// ordered by the `y` coordinate

	private var startIndex = 0


	private var contentTop: CGFloat {
		return orderedCells.first?.top ?? MASTER_OFFSET
	}


	private var contentBottom: CGFloat {
		return orderedCells.last?.bottom ?? MASTER_OFFSET
	}


	convenience init(parentWindowWidth: CGFloat) {
		self.init()
		frame = CGRect(x: 0, y: -MASTER_OFFSET, width: parentWindowWidth, height: CONTENT_HEIGHT)

		let indicatorSide: CGFloat = 20
		refreshIndicator = UIActivityIndicatorView(frame: CGRect(x: (parentWindowWidth - indicatorSide) / 2, y: MASTER_OFFSET + REFRESH_INDICATOR_TOP_OFFSET, width: indicatorSide, height: indicatorSide))
		refreshIndicator.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
		refreshIndicator.style = .gray
		addSubview(refreshIndicator)
	}


	internal func startIndexForEdge(_ edge: RollingView.Edge, newViewCount count: Int) -> Int {
		switch edge {
		case .top:
			return startIndex - count
		case .bottom:
			return startIndex + orderedCells.count
		}
	}


	internal func addCells(to edge: RollingView.Edge, cells: [RollingViewCell]) -> CGFloat {
		var totalHeight: CGFloat = 0

		switch edge {

		case .top:
			self.startIndex -= cells.count
			var newCells: [Placeholder] = []
			var top: CGFloat = contentTop
			for cell in cells.reversed() {
				let cellHeight = cell.frame.height
				top -= cellHeight
				totalHeight += cellHeight
				cell.frame.top = top
				newCells.append(Placeholder(view: cell))
				self.addSubview(cell)
			}
			orderedCells.insert(contentsOf: newCells.reversed(), at: 0)

		case .bottom:
			for cell in cells {
				let cellHeight = cell.frame.height
				totalHeight += cellHeight
				cell.frame.top = contentBottom
				orderedCells.append(Placeholder(view: cell))
				self.addSubview(cell)
			}
		}

		refreshIndicator.frame.top = contentTop + REFRESH_INDICATOR_TOP_OFFSET
		return totalHeight
	}


	internal func cellFromPoint(_ point: CGPoint) -> RollingViewCell? {
		let index = orderedCells.binarySearch(top: point.y) - 1
		if index >= 0 && index < orderedCells.count, let cell = orderedCells[index].cachedView, cell.frame.contains(point) {
			return cell
		}
		return nil
	}
}



private extension Array where Element == RollingViewContent.Placeholder {
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
