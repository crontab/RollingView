//
//  RollingView.swift
//  RollingView
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


protocol RollingViewDelegate: class {
	func rollingView(_ rollingView: RollingView, reuseCell: UIView, forIndex index: Int)
	func rollingViewCanAddCellsAbove(_ rollingView: RollingView, completion: @escaping (_ tryAgain: Bool) -> Void)
}



class RollingView: UIScrollView {

	// MARK: - Public

	enum Edge: Int {
		case top
		case bottom
	}

	weak var rollingViewDelegate: RollingViewDelegate?

	var warmCellCount: Int = 5


	func register(cellClass: UIView.Type, create: @escaping () -> UIView) {
		recyclePool.register(cellClass: cellClass, create: create)
	}


	func addCells(edge: Edge, cellClass: UIView.Type, count: Int) {
		guard count > 0 else {
			loadingMore = false
			return
		}
		let startIndex = startIndexForEdge(edge, newViewCount: count)
		let views = (startIndex..<(startIndex + count)).map { (index) -> UIView in
			return self.recyclePool.dequeue(forIndex: index, cellClass: cellClass, width: contentView.frame.width, reuseCell: reuseCell)
		}
		let totalHeight = addCells(to: edge, cells: views)
		validateVisibleRect()
		contentDidAddSpace(edge: edge, addedHeight: totalHeight)
	}


	func cellFromPoint(_ point: CGPoint) -> UIView? {
		let point = convert(point, to: contentView)
		let index = placeholders.binarySearch(top: point.y) - 1
		if index >= 0 && index < placeholders.count, let cell = placeholders[index].cell, cell.frame.contains(point) {
			return cell
		}
		return nil
	}


	// MARK: - Protected; scroller

	private var contentView: UIView!
	private var recyclePool = CommonPool()
	private var firstLayout = true


	override func awakeFromNib() {
		super.awakeFromNib()
		contentView = createContentView(parentWindowWidth: frame.width, backgroundColor: backgroundColor)
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
				refreshIndicator.startAnimating()
			}
			else {
				refreshIndicator.stopAnimating()
			}
		}
	}


	override var contentOffset: CGPoint {
		didSet {
			validateVisibleRect()
			if !firstLayout && !reachedEnd && !loadingMore {
				let offset = contentOffset.y + contentInset.top + safeAreaInsets.top
				if offset < frame.height { // try to load a screenful more cells above the existing content
					loadingMore = true
					DispatchQueue.main.async(execute: tryLoadMore)
				}
			}
		}
	}


	private func reuseCell(_ reuseCell: UIView, forIndex index: Int) -> UIView {
		rollingViewDelegate!.rollingView(self, reuseCell: reuseCell, forIndex: index)
		return reuseCell
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


	private func contentDidAddSpace(edge: Edge, addedHeight: CGFloat) {
		layout()

		let distanceToBottom = contentSize.height + contentInset.bottom - (contentOffset.y + bounds.height)
		contentSize.height += addedHeight

		switch edge {
		case .top:
			let delta = safeBoundsHeight - contentInset.top - contentInset.bottom - contentSize.height
			contentOffset.y += max(0, min(addedHeight, -delta))
			contentView.frame.origin.y += addedHeight

		case .bottom:
			if distanceToBottom < 20 {
				UIView.transition(with: self, duration: 0.25, options: .curveEaseInOut, animations: {
					self.scrollRectToVisible(CGRect(x: 0, y: self.contentSize.height - 1, width: 1, height: 1), animated: false)
				})
			}
		}

		loadingMore = false
	}


	// MARK: - Protected; cell management


	private static let CONTENT_HEIGHT: CGFloat = 10_000_000
	private static let MASTER_OFFSET = CONTENT_HEIGHT / 2
	private static let REFRESH_INDICATOR_TOP_OFFSET: CGFloat = -28


	private var refreshIndicator: UIActivityIndicatorView!

	override var backgroundColor: UIColor? {
		didSet { contentView?.backgroundColor = backgroundColor }
	}

	private func createContentView(parentWindowWidth: CGFloat, backgroundColor: UIColor?) -> UIView {
		let view = UIView(frame: CGRect(x: 0, y: -Self.MASTER_OFFSET, width: parentWindowWidth, height: Self.CONTENT_HEIGHT))
		view.backgroundColor = backgroundColor
		let indicatorSide: CGFloat = 20
		refreshIndicator = UIActivityIndicatorView(frame: CGRect(x: (parentWindowWidth - indicatorSide) / 2, y: Self.MASTER_OFFSET + Self.REFRESH_INDICATOR_TOP_OFFSET, width: indicatorSide, height: indicatorSide))
		refreshIndicator.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
		refreshIndicator.style = .gray
		view.addSubview(refreshIndicator)
		return view
	}


	fileprivate struct Placeholder {
		var cell: UIView? // can be discarded to save memory; this provides our caching mechanism essentially (not yet)
		var cellClass: UIView.Type
		var top: CGFloat
		var height: CGFloat

		var bottom: CGFloat {
			return top + height
		}

		init(cellClass: UIView.Type, top: CGFloat, height: CGFloat) {
			self.cellClass = cellClass
			self.top = top
			self.height = height
		}

		init(cell: UIView) {
			self.cell = cell
			self.cellClass = type(of: cell)
			self.top = cell.frame.minY
			self.height = cell.frame.height
		}

		mutating func detach() -> UIView {
			let temp = cell!
			temp.removeFromSuperview()
			cell = nil
			return temp
		}

		mutating func attach(cell: UIView, toSuperview superview: UIView) {
			precondition(self.cell == nil)
			self.cell = cell
			cell.frame.origin.y = top
			cell.frame.size.height = height
			superview.addSubview(cell)
		}
	}


	private var placeholders: [Placeholder] = []	// ordered by the `y` coordinate

	// Always negative or 0; from the user's perspective the cells added to the top have negative indices
	private var userStartIndex = 0

	// Our "hot" area calculated in validateVisibleRect()
	private var topHotIndex = 0
	private var bottomHotIndex = 0


	private var contentTop: CGFloat {
		return placeholders.first?.top ?? Self.MASTER_OFFSET
	}


	private var contentBottom: CGFloat {
		return placeholders.last?.bottom ?? Self.MASTER_OFFSET
	}


	private func startIndexForEdge(_ edge: RollingView.Edge, newViewCount count: Int) -> Int {
		switch edge {
		case .top:
			return userStartIndex - count
		case .bottom:
			return userStartIndex + placeholders.count
		}
	}


	private func addCells(to edge: RollingView.Edge, cells: [UIView]) -> CGFloat {
		var totalHeight: CGFloat = 0

		switch edge {

		case .top:
			userStartIndex -= cells.count
			// We add the new cells reversed to the local temp array first, then insert into the global one in reverse order again; this way it's easier to calculate the coordinates
			var newCells: [Placeholder] = []
			var top: CGFloat = contentTop
			for cell in cells.reversed() {
				let cellHeight = cell.frame.height
				top -= cellHeight
				totalHeight += cellHeight
				cell.frame.origin.y = top

				// If the hot window is not at the top, then add a placeholder and send the poor cell to the recycling pool
				if topHotIndex > 0 {
					newCells.append(Placeholder(cellClass: type(of: cell), top: top, height: cellHeight))
					recyclePool.enqueue(cell)
				}
				else {
					newCells.append(Placeholder(cell: cell))
					contentView.addSubview(cell)
				}
			}
			placeholders.insert(contentsOf: newCells.reversed(), at: 0)

		case .bottom:
			for cell in cells {
				let cellHeight = cell.frame.height
				totalHeight += cellHeight
				cell.frame.origin.y = contentBottom

				// If this is beyond our hot area, then add a placeholder and send the poor cell to the recycling pool
				if bottomHotIndex < placeholders.count - 1 {
					placeholders.append(Placeholder(cellClass: type(of: cell), top: contentBottom, height: cellHeight))
					recyclePool.enqueue(cell)
				}
				else {
					placeholders.append(Placeholder(cell: cell))
					contentView.addSubview(cell)
				}
			}
		}

		refreshIndicator.frame.origin.y = contentTop + Self.REFRESH_INDICATOR_TOP_OFFSET
		return totalHeight
	}


	private func validateVisibleRect() {
		guard let contentView = contentView, rollingViewDelegate != nil, !placeholders.isEmpty else {
			return
		}

		let rect = convert(bounds, to: contentView)

		// TODO: skip if the change wasn't significant

		// 2 screens of cells should be kept "hot" in memory, i.e. half-screen above and half-screen below the visible rect objects should be available
		let hotRect = rect.insetBy(dx: 0, dy: -rect.height / 2)

		topHotIndex = max(0, placeholders.binarySearch(top: hotRect.minY) - 1)
		var index = topHotIndex
		repeat {
			if placeholders[index].cell == nil {
				let cell = recyclePool.dequeue(forIndex: index + userStartIndex, cellClass: placeholders[index].cellClass, width: contentView.frame.width, reuseCell: reuseCell)
				placeholders[index].attach(cell: cell, toSuperview: contentView)
			}
			index += 1
		} while index < placeholders.count && placeholders[index].bottom < hotRect.maxY
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
			RLOG("RollingView: discarding at \(index + userStartIndex)")
			index += 1
		}
	}


	// MARK: - Protected; recycle pool

	private class CommonPool {

		func register(cellClass: UIView.Type, create: @escaping () -> UIView) {
			let key = ObjectIdentifier(cellClass)
			precondition(dict[key] == nil, "RollingView cell class \(cellClass) already registered")
			dict[key] = Pool(create: create)
		}

		func enqueue(_ element: UIView) {
			let key = ObjectIdentifier(type(of: element))
			precondition(dict[key] != nil, "RollingView cell class \(type(of: element)) not registered")
			dict[key]!.enqueue(element)
		}

		func dequeue(forIndex index: Int, cellClass: UIView.Type, width: CGFloat, reuseCell: (UIView, Int) -> UIView) -> UIView {
			let key = ObjectIdentifier(cellClass)
			precondition(dict[key] != nil, "RollingView cell class \(cellClass) not registered")
			let cell = dict[key]!.dequeueOrCreate()
			cell.frame.size.width = width
			return reuseCell(cell, index)
		}

		private struct Pool {
			var create: () -> UIView
			var array: [UIView] = []

			mutating func enqueue(_ element: UIView) {
				RLOG("RollingView: recycling cell, pool: \(array.count)")
				array.append(element)
			}

			mutating func dequeueOrCreate() -> UIView {
				if !array.isEmpty {
					RLOG("RollingView: reusing cell, pool: \(array.count)")
					return array.removeLast()
				}
				else {
					RLOG("RollingView: ALLOC")
					return create()
				}
			}
		}

		private var dict: [ObjectIdentifier: Pool] = [:]
	}
}



private extension Array where Element == RollingView.Placeholder {
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


#if DEBUG && DEBUG_ROLLING_VIEW
	private func RLOG(_ s: String) { print(s) }
#else
	private func RLOG(_ s: String) { }
#endif

