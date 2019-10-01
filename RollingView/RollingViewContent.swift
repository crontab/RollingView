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



#if DEBUG && DEBUG_ROLLING_VIEW
	@inlinable internal func RLOG(_ s: String) { print(s) }
#else
	@inlinable internal func RLOG(_ s: String) { }
#endif



class RollingViewContent: UIView {

	fileprivate struct Placeholder {
		var cell: RollingViewCell? // can be discarded to save memory; this provides our caching mechanism essentially (not yet)
		var cellClass: RollingViewCell.Type
		var top: CGFloat
		var height: CGFloat

		var bottom: CGFloat {
			return top + height
		}

		init(cellClass: RollingViewCell.Type, top: CGFloat, height: CGFloat) {
			self.cellClass = cellClass
			self.top = top
			self.height = height
		}

		init(cell: RollingViewCell) {
			self.cell = cell
			self.cellClass = type(of: cell)
			self.top = cell.frame.top
			self.height = cell.frame.height
		}

		mutating func detach() -> RollingViewCell {
			let temp = cell!
			temp.removeFromSuperview()
			cell = nil
			return temp
		}

		mutating func attach(cell: RollingViewCell, toSuperview superview: UIView) {
			precondition(self.cell == nil)
			self.cell = cell
			cell.frame.origin.y = top
			cell.frame.size.height = height
			superview.addSubview(cell)
		}
	}


	internal var refreshIndicator: UIActivityIndicatorView!

	private var placeholders: [Placeholder] = []	// ordered by the `y` coordinate

	// Always negative or 0; from the user's perspective the cells added to the top have negative indices
	private var userStartIndex = 0

	// Our "hot" area calculated in validateVisibleRect()
	private var topHotIndex = 0
	private var bottomHotIndex = 0


	private var contentTop: CGFloat {
		return placeholders.first?.top ?? MASTER_OFFSET
	}


	private var contentBottom: CGFloat {
		return placeholders.last?.bottom ?? MASTER_OFFSET
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
			return userStartIndex - count
		case .bottom:
			return userStartIndex + placeholders.count
		}
	}


	internal func addCells(to edge: RollingView.Edge, cells: [RollingViewCell], recyclePool: RollingViewPool) -> CGFloat {
		var totalHeight: CGFloat = 0

		switch edge {

		case .top:
			self.userStartIndex -= cells.count
			// We add the new cells reversed to the local temp array first, then insert into the global one in reverse order again; this way it's easier to calculate the coordinates
			var newCells: [Placeholder] = []
			var top: CGFloat = contentTop
			for cell in cells.reversed() {
				let cellHeight = cell.frame.height
				top -= cellHeight
				totalHeight += cellHeight
				cell.frame.top = top

				// If the hot window is not at the top, then add a placeholder and send the poor cell to the recycling pool
				if topHotIndex > 0 {
					newCells.append(Placeholder(cellClass: type(of: cell), top: top, height: cellHeight))
					recyclePool.enqueue(cell)
				}
				else {
					newCells.append(Placeholder(cell: cell))
					self.addSubview(cell)
				}
			}
			placeholders.insert(contentsOf: newCells.reversed(), at: 0)

		case .bottom:
			for cell in cells {
				let cellHeight = cell.frame.height
				totalHeight += cellHeight
				cell.frame.top = contentBottom

				// If this is beyond our hot area, then add a placeholder and send the poor cell to the recycling pool
				if bottomHotIndex < placeholders.count - 1 {
					placeholders.append(Placeholder(cellClass: type(of: cell), top: contentBottom, height: cellHeight))
					recyclePool.enqueue(cell)
				}
				else {
					placeholders.append(Placeholder(cell: cell))
					self.addSubview(cell)
				}
			}
		}

		refreshIndicator.frame.top = contentTop + REFRESH_INDICATOR_TOP_OFFSET
		return totalHeight
	}


	internal func validateVisibleRect(toRect rect: CGRect, recyclePool: RollingViewPool, warmCellCount: Int) {

		guard !placeholders.isEmpty else {
			return
		}

		// TODO: skip if the change wasn't significant

		// 2 screens of cells should be kept "hot" in memory, i.e. half-screen above and half-screen below the visible rect objects should be available
		let hotRect = rect.insetBy(dx: 0, dy: -rect.height / 2)

		topHotIndex = max(0, placeholders.binarySearch(top: hotRect.top) - 1)
		var index = topHotIndex
		repeat {
			if placeholders[index].cell == nil {
				let cell = recyclePool.dequeue(forIndex: index + userStartIndex, cellClass: placeholders[index].cellClass, width: frame.width)
				placeholders[index].attach(cell: cell, toSuperview: self)
			}
			index += 1
		} while index < placeholders.count && placeholders[index].bottom < hotRect.bottom
		bottomHotIndex = index - 1

		// Expand the hot area by warmCellCount more cells in both directions; everything beyond that can be freed:
		index = topHotIndex - warmCellCount
		while index >= 0 && placeholders[index].cell != nil {
			let detachedCell = placeholders[index].detach()
			recyclePool.enqueue(detachedCell)
			index -= 1
		}

		index = bottomHotIndex + warmCellCount
		while index < placeholders.count && placeholders[index].cell != nil {
			let detachedCell = placeholders[index].detach()
			recyclePool.enqueue(detachedCell)
			RLOG("RollingView: discarding at \(index + userStartIndex), recyclePool: \(recyclePool.count)")
			index += 1
		}
	}


	internal func cellFromPoint(_ point: CGPoint) -> RollingViewCell? {
		let index = placeholders.binarySearch(top: point.y) - 1
		if index >= 0 && index < placeholders.count, let cell = placeholders[index].cell, cell.frame.contains(point) {
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
