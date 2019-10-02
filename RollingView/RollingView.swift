//
//  RollingView.swift
//  RollingView
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


protocol RollingViewDelegate: class {

	/// Set up a cell to be inserted into the RollingView object. This method is called either in response to your call to `addCells(...)` or when a cell is pulled from the recycle pool and needs to be set up for a given index position in the view. The class of the view is the same is when a cell was added using `addCells(...)` at a given position.
	func rollingView(_ rollingView: RollingView, reuseCell: UIView, forIndex index: Int)

	func rollingView(_ rollingView: RollingView, reached edge: RollingView.Edge, completion: @escaping (_ hasMore: Bool) -> Void)
}


extension RollingViewDelegate {
	func rollingView(_ rollingView: RollingView, reached edge: RollingView.Edge, completion: @escaping (_ hasMore: Bool) -> Void) {
		completion(false)
	}
}


/// A powerful infinite scroller suitable for e.g. chat apps. With RollingView you can add content in both directions; the class also manages memory in the most efficient way by reusing cells. RollingView can contain horizontal cells of any subclass of UIView. Content in either direction can be added either programmatically or in response to hitting one of the edges of the existing content, i.e. top or bottom.
class RollingView: UIScrollView {

	// MARK: - Public

	enum Edge: Int {
		case top
		case bottom
	}

	/// See RollingViewDelegate: you need to implement at least `rollingView(_:reuseCell:forIndex:)`
	weak var rollingViewDelegate: RollingViewDelegate?

	/// The area that should be kept "hot" in memory expressed in number of screens beyond the visible part. Value of 1 means half a screen above and half a screen below will be kept hot, the rest may be discarded and the cells sent to the recycle pool for further reuse.
	var hotAreaFactor: CGFloat = 1 {
		didSet { precondition(hotAreaFactor >= 1) }
	}

	/// Extra cells to keep "warm" in memory in each direction, in addition to the "hot" part. "Warm" means the cells will not be discarded immediately, however neither are they required to be in memory yet like in the hot part. This provides certain inertia in how cells are discarded and reused.
	var warmCellCount: Int = 10 {
		didSet { precondition(warmCellCount >= 2) }
	}

	/// Register a cell class along with its factory method create()
	func register(cellClass: UIView.Type, create: @escaping () -> UIView) {
		recyclePool.register(cellClass: cellClass, create: create)
	}

	/// Tell RollingView that cells should be added either on top or to the bottom of the existing content. Your `rollingView(_:reuseCell:forIndex:)` implementation will be called for each of the added cells.
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

	/// Returns a cell given a point on screen in RollingVIew's coordinate space.
	func cellFromPoint(_ point: CGPoint) -> UIView? {
		let point = convert(point, to: contentView)
		let index = placeholders.binarySearch(top: point.y) - 1
		if index >= 0 && index < placeholders.count, let cell = placeholders[index].cell, cell.frame.contains(point) {
			return cell
		}
		return nil
	}

	/// Scrolls to the bottom of content; useful when new cells appear at the bottom in a chat roll
	func scrollToBottom(animated: Bool) {
		self.scrollRectToVisible(CGRect(x: 0, y: self.contentSize.height - 1, width: 1, height: 1), animated: animated)
	}

	/// Checks if the scroller is within 20 points from the bottom; useful when deciding whether the view should be automatically scrolled to the bottom when adding new cells.
	var isCloseToBottom: Bool {
		return isCloseToBottom(within: 20)
	}


	// MARK: - Protected; scroller

	private var contentView: UIView!
	private var firstLayout = true


	override init(frame: CGRect) {
		super.init(frame: frame)
		setupContentView()
	}


	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupContentView()
	}


	override var backgroundColor: UIColor? {
		didSet { contentView?.backgroundColor = backgroundColor }
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


	private var reachedTop: Bool = false
	private var reachedBottom: Bool = false

	override var contentOffset: CGPoint {
		didSet {
			guard !firstLayout else {
				return
			}
			validateVisibleRect()
			if !reachedTop && !loadingMore {
				let offset = contentOffset.y + contentInset.top + safeAreaInsets.top
				if offset < frame.height / 2 { // try to load a screenful more cells above the existing content
					loadingMore = true
					self.reachedTop = true
					self.tryLoadMore(edge: .top)
				}
			}
			if !reachedBottom && isCloseToBottom(within: frame.height / 2) {
				self.reachedBottom = true
				self.tryLoadMore(edge: .bottom)
			}
		}
	}


	private func reuseCell(_ reuseCell: UIView, forIndex index: Int) -> UIView {
		rollingViewDelegate!.rollingView(self, reuseCell: reuseCell, forIndex: index)
		return reuseCell
	}


	func isCloseToBottom(within pixels: CGFloat) -> Bool {
		return (contentSize.height + contentInset.bottom - (contentOffset.y + bounds.height)) < pixels
	}


	private func tryLoadMore(edge: Edge) {
		rollingViewDelegate?.rollingView(self, reached: edge) { (hasMore) in
			switch edge {
			case .top:
				self.loadingMore = false
				self.reachedTop = !hasMore
			case .bottom:
				self.reachedBottom = !hasMore
			}
		}
	}


	private func contentDidAddSpace(edge: Edge, addedHeight: CGFloat) {
		layout()
		contentSize.height += addedHeight
		switch edge {
		case .top:
			// The magic part of RollingView: when extra space is added on top, contentView and contentSize are adjusted here to create an illusion of infinite expansion:
			let delta = bounds.height - safeAreaInsets.bottom - safeAreaInsets.top - contentInset.top - contentInset.bottom - contentSize.height
			contentOffset.y += max(0, min(addedHeight, -delta))
			contentView.frame.origin.y += addedHeight
		case .bottom:
			break
		}
		loadingMore = false
	}


	// MARK: - internal: contentView

	private static let CONTENT_HEIGHT: CGFloat = 10_000_000
	private static let MASTER_OFFSET = CONTENT_HEIGHT / 2
	private static let REFRESH_INDICATOR_TOP_OFFSET: CGFloat = -28
	private static let REFRESH_INDICATOR_SIZE: CGFloat = 20

	private var refreshIndicator: UIActivityIndicatorView!


	private func setupContentView() {
		precondition(contentView == nil)

		let view = UIView(frame: CGRect(x: 0, y: -Self.MASTER_OFFSET, width: frame.width, height: Self.CONTENT_HEIGHT))
		view.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
		view.backgroundColor = backgroundColor

		refreshIndicator = UIActivityIndicatorView(frame: CGRect(
			x: (view.frame.width - Self.REFRESH_INDICATOR_SIZE) / 2,
			y: Self.MASTER_OFFSET + Self.REFRESH_INDICATOR_TOP_OFFSET,
			width: Self.REFRESH_INDICATOR_SIZE,
			height: Self.REFRESH_INDICATOR_SIZE))
		refreshIndicator.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
		refreshIndicator.style = .gray
		view.addSubview(refreshIndicator)

		insertSubview(view, at: 0)
		contentView = view
	}


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


	// MARK: - internal: cell management

	private var recyclePool = CommonPool()
	private var placeholders: [Placeholder] = []	// ordered by the `y` coordinate so that binarySearch() can be used on it

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


	private func startIndexForEdge(_ edge: Edge, newViewCount count: Int) -> Int {
		switch edge {
		case .top:
			return userStartIndex - count
		case .bottom:
			return userStartIndex + placeholders.count
		}
	}


	private func addCells(to edge: Edge, cells: [UIView]) -> CGFloat {
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

				// If the hot window is not at the top, then add a placeholder and send the cell to the recycling pool
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

				// If this is beyond our hot area, then add a placeholder and send the cell to the recycling pool
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

		// Certain number of screens should be kept "hot" in memory, e.g. for hotAreaFactor=1 half-screen above and half-screen below the visible area all objects should be available
		let hotRect = rect.insetBy(dx: 0, dy: -(rect.height * hotAreaFactor / 2))

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
		index = topHotIndex - warmCellCount / 2
		while index >= 0 && placeholders[index].cell != nil {
			let detachedCell = placeholders[index].detach()
			recyclePool.enqueue(detachedCell)
			index -= 1
		}

		index = bottomHotIndex + warmCellCount / 2
		while index < placeholders.count && placeholders[index].cell != nil {
			let detachedCell = placeholders[index].detach()
			recyclePool.enqueue(detachedCell)
			RLOG("RollingView: discarding at \(index + userStartIndex)")
			index += 1
		}
	}


	// MARK: - internal classes

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


	fileprivate struct Placeholder {
		var cell: UIView? // can be discarded to save memory
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

