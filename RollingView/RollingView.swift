//
//  RollingView.swift
//  RollingView
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


public protocol RollingViewDelegate: AnyObject {

	/// Set up a cell to be inserted into the RollingView object. This method is called either in response to your call to `addCells(...)` or when a cell is pulled from the recycle pool and needs to be set up for a given index position in the view. The class of the view is the same is when a cell was added using `addCells(...)` at a given position.
	func rollingView(_ rollingView: RollingView, reuseCell: UIView, forIndex index: Int)

	/// Try to load more data and create cells accordingly, possibly asynchronously. `completion` takes a boolean parameter that indicates whether more attempts should be made for a given `edge` in the future. Once `completion` returns false this delegate method will not be called again for a given `edge`. Optional.
	func rollingView(_ rollingView: RollingView, reached edge: RollingView.Edge, completion: @escaping (_ hasMore: Bool) -> Void)

	/// Cell at `index` has been tapped; optional. No visual changes take place in this case. If `cell` is not nil, it means the cell is visible on screen or is in the "hot" area, so you can make changes in it to reflect the gesture.
	func rollingView(_ rollingView: RollingView, didSelectCell cell: UIView?, atIndex index: Int)
}


public extension RollingViewDelegate {
	func rollingView(_ rollingView: RollingView, reached edge: RollingView.Edge, completion: @escaping (_ hasMore: Bool) -> Void) { completion(false) }

	func rollingView(_ rollingView: RollingView, didSelectCell: UIView?, atIndex index: Int) { }
}


/// A powerful infinite scroller suitable for e.g. chat apps. With RollingView you can add content in both directions; the class also manages memory in the most efficient way by reusing cells. RollingView can contain horizontal cells of any subclass of UIView. Content in either direction can be added either programmatically or in response to hitting one of the edges of the existing content, i.e. top or bottom.
open class RollingView: UIScrollView {

	// MARK: - Public

	public enum Edge: Int {
		case top
		case bottom
	}


	/// See RollingViewDelegate: you need to implement at least `rollingView(_:reuseCell:forIndex:)`
	public weak var rollingViewDelegate: RollingViewDelegate?


	/// Set this if the height of cells is known, or give some estimated (non-zero) value. When your cells have this exact height, RollingView can be more efficient especially when adding new cells.
	public var estimatedCellHeight: CGFloat = 44 {
		didSet { precondition(estimatedCellHeight >= 1) }
	}


	/// The area that should be kept "hot" in memory expressed in number of screens beyond the visible part. Value of 1 means half a screen above and half a screen below will be kept hot, the rest may be discarded and the cells sent to the recycle pool for further reuse.
	public var hotAreaFactor: CGFloat = 1 {
		didSet { precondition(hotAreaFactor >= 1) }
	}


	/// Extra cells to keep "warm" in memory in each direction, in addition to the "hot" part. "Warm" means the cells will not be discarded immediately, however neither are they required to be in memory yet like in the hot part. This provides certain inertia in how cells are discarded and reused.
	public var warmCellCount: Int = 10 {
		didSet { precondition(warmCellCount >= 2) }
	}


	/// Register a cell class along with its factory method create()
	public func register<T: UIView>(cellClass: T.Type, create: @escaping () -> T) {
		recyclePool.register(cellClass: cellClass, create: create)
	}


	/// Preallocate a given number of cells of class `cellClass` to be reused later as necessary. The class should be registered prior to this using `register(cellClass:create:)`.
	public func preallocate<T: UIView>(_ count: Int, cellClass: T.Type) {
		recyclePool.preallocate(count, cellClass: cellClass)
	}


	/// Tell RollingView that cells should be added either on top or to the bottom of the existing content. Your `rollingView(_:reuseCell:forIndex:)` implementation may be called for some or all of the added cells.
	public func addCells(edge: Edge, cellClass: UIView.Type, count: Int, animated: Bool) {
		guard count > 0 else {
			return
		}
		doAddCells(edge: edge, cellClass: cellClass, count: count, animated: animated)
	}


	/// Tell RollingView that cells should be inserted starting at `index`. Your `rollingView(_:reuseCell:forIndex:)` implementation may be called for some or all of the inserted cells.
	public func insertCells(at index: Int, cellClass: UIView.Type, count: Int) {
		guard count > 0 else {
			return
		}
		doInsertCells(at: index, cellClass: cellClass, count: count)
	}


	/// Removes cells and saves them for recycling if there are any allocated within a given range
	public func removeCells(at index: Int, count: Int) {
		guard count > 0 else {
			return
		}
		doRemoveCells(at: index, count: count)
	}


	/// Replace a cell with another one at a given index, possibly of a different class and different height, too
	public func replaceCell(at index: Int, cellClass: UIView.Type) {
		doReplaceCell(at: index, cellClass: cellClass)
	}


	/// Total number of cells in the view, instantiated or not
	public var count: Int { placeholders.count }


	/// Set a new number of cells; cells can be added or removed depending on which way the value changes
	public func setCount(_ newValue: Int, cellClass: UIView.Type, reload: Bool) {
		let delta = newValue - placeholders.count
		if delta < 0 {
			removeCells(at: newValue, count: -delta)
		}
		if reload {
			self.reload()
		}
		if delta > 0 {
			addCells(edge: .bottom, cellClass: cellClass, count: delta, animated: false)
		}
	}


	/// Return a cell view at given index if it's "warm" in memory, or nil otherwise
	public func cellAt(_ index: Int) -> UIView? {
		return placeholders[index].cell
	}


	/// Return all "live" cells in the hot area
	public var visibleCells: [UIView] {
		hotCellRange().compactMap { placeholders[$0].cell }
	}


	/// Remove all cells and empty the recycle pool. Header and footer views remain intact.
	public func clear() {
		clearContent()
		clearCells()
		reachedEdge = [false, false]
	}


	/// Tell RollingView to call your delegate method `rollingView(_:reuseCell:forIndex:)` on the cell at `index` if it's instantiated and is warm, i.e. close or inside the visible area. In the delegate method, the cell has a chance to change its appearance and height.
	public func reloadCell(at index: Int) {
		doReloadCell(at: index)
	}


	/// Works like `reloadCell(at:)` on all currently instantiated cells in the warm area.
	public func reload() {
		doReloadAll()
	}


	/// Returns a cell index for given a point on screen in RollingView's coordinate space.
	public func cellIndexFromPoint(_ point: CGPoint) -> Int? {
		let point = convert(point, to: contentView)
		let index = placeholders.binarySearch(top: point.y) - 1
		if placeholders.indices ~= index && placeholders[index].containsPoint(point) {
			return index
		}
		return nil
	}


	/// Returns a frame of a given cell index in RollingView's coordinates.
	public func frameOfCell(at index: Int) -> CGRect {
		let placeholder = placeholders[index]
		let origin = convert(CGPoint(x: contentView.frame.origin.x, y: placeholder.top), from: contentView)
		return CGRect(x: origin.x, y: origin.y, width: contentView.frame.width, height: placeholder.height)
	}


	/// Scrolls to the bottom of content; useful when new cells appear at the bottom in a chat roll
	public func scrollToBottom(animated: Bool) {
		scrollRectToVisible(CGRect(x: 0, y: self.contentSize.height - 1, width: 1, height: 1), animated: animated)
	}


	/// Scrolls to the top of content
	public func scrollToTop(animated: Bool) {
		scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: animated)
	}


	/// Scrolls to the cell by its index
	public func scrollToCellIndex(_ index: Int, animated: Bool) {
		// We allow scrolling to index 0 if there are no cells; useful when there's a header and we still want to scroll to the top of content
		if index == 0 && placeholders.isEmpty {
			let origin = convert(CGPoint(x: 0, y: contentTop), from: contentView)
			scrollRectToVisible(CGRect(x: 0, y: origin.y, width: 1, height: 1), animated: animated)
		}
		else {
			scrollRectToVisible(frameOfCell(at: index), animated: animated)
		}
	}


	/// Checks if the scroller is within 20 points from the bottom; useful when deciding whether the view should be automatically scrolled to the bottom when adding new cells.
	public var isCloseToBottom: Bool {
		return isCloseToBottom(within: 20)
	}


	/// Header view, similar to UITableView's
	public var headerView: UIView? {
		willSet {
			headerView.map {
				$0.removeFromSuperview()
				updateContentLayout(edgeHint: .top)
			}
		}
		didSet {
			headerView.map {
				resizeComponent($0)
				contentView.addSubview($0)
				updateContentLayout(edgeHint: .top)
			}
		}
	}


	/// Footer view, similar to UITableView's
	public var footerView: UIView? {
		willSet {
			footerView.map {
				$0.removeFromSuperview()
				updateContentLayout(edgeHint: .bottom)
			}
		}
		didSet {
			footerView.map {
				resizeComponent($0)
				contentView.addSubview($0)
				updateContentLayout(edgeHint: .bottom)
			}
		}
	}


	// MARK: - internal: scroller

	private var contentView: UIView!


	private func resizeComponent(_ view: UIView) {
		let fittingSize = CGSize(width: contentView.frame.width, height: UIView.layoutFittingCompressedSize.height)
		view.frame.size = view.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .defaultLow)
	}


	public override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}


	public required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}


	open override func layoutSubviews() {
		super.layoutSubviews()
		// TODO: this should re-layout all the living cells when the container width changes
		headerView.map {
			resizeComponent($0)
		}
		footerView.map {
			resizeComponent($0)
		}
	}


	open override var backgroundColor: UIColor? {
		didSet { contentView?.backgroundColor = backgroundColor }
	}


	private var reachedEdge = [false, false]
	private var skipEdgeChecks: Int = 0

	public override var contentOffset: CGPoint {
		didSet {
			validateVisibleRect()
			guard skipEdgeChecks == 0 else {
				return
			}
			if !reachedEdge[Edge.top.rawValue] {
				let offset = contentOffset.y + contentInset.top + safeAreaInsets.top
				// Try to load more conent if the top of content is half a screen away
				if offset < frame.height / 2 {
					reachedEdge[Edge.top.rawValue] = true // prevent reentrance
					tryLoadMore(edge: .top)
				}
			}
			// Also try to load more content at the bottom
			if !reachedEdge[Edge.bottom.rawValue] && isCloseToBottom(within: frame.height / 2) {
				reachedEdge[Edge.bottom.rawValue] = true // prevent reentrance
				tryLoadMore(edge: .bottom)
			}
		}
	}


	private func reuseCell(_ cell: UIView, forIndex index: Int) {
		rollingViewDelegate?.rollingView(self, reuseCell: cell, forIndex: index)
		resizeComponent(cell)
	}


	func isCloseToBottom(within pixels: CGFloat) -> Bool {
		return (contentSize.height + contentInset.bottom - (contentOffset.y + bounds.height)) < pixels
	}


	private func tryLoadMore(edge: Edge) {
		guard let delegate = rollingViewDelegate else {
			reachedEdge[edge.rawValue] = false // try again later
			return
		}
		DispatchQueue.main.async { [self] in
			delegate.rollingView(self, reached: edge) { [self] (hasMore) in
				reachedEdge[edge.rawValue] = !hasMore
			}
		}
	}


	// MARK: - internal: gestures


	private func setup() {
		addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap(_:))))
		setupContentView()
	}


	@objc private func onTap(_ sender: UITapGestureRecognizer) {
		if sender.state == .ended {
			if let index = cellIndexFromPoint(sender.location(in: self)) {
				rollingViewDelegate?.rollingView(self, didSelectCell: placeholders[index].cell, atIndex: index)
			}
		}
	}


	// MARK: - internal: contentView

	private static let CONTENT_HEIGHT: CGFloat = 10_000_000
	private static let MASTER_OFFSET = CONTENT_HEIGHT / 2
	private static let ANIMATION_DURATION = 0.25


	private func setupContentView() {
		precondition(contentView == nil)
		let view = UIView(frame: CGRect(x: 0, y: -Self.MASTER_OFFSET, width: frame.width, height: Self.CONTENT_HEIGHT))
		view.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
		insertSubview(view, at: 0)
		contentView = view
	}


	private func updateContentLayout(edgeHint: Edge) {
		skipEdgeChecks += 1
		defer {
			skipEdgeChecks -= 1
		}

		contentSize.width = frame.width
		let newContentHeight = (contentBottom - contentTop) + headerHeight + footerHeight
		let addedHeight = newContentHeight - contentSize.height
		guard addedHeight != 0 else {
			return
		}
		contentSize.height = newContentHeight

		switch edgeHint {

			case .top:
				headerView?.frame.origin.y = contentTop - (headerView?.frame.height ?? 0)

				// The magic part of RollingView: when extra space is added on top, contentView and contentSize are adjusted here to create an illusion of infinite expansion.
				// The below is to ensure that when new content is added on top, the scroller doesn't move visually (though it does in terms of relative coordinates). It gets a bit trickier when the overall size of content is smaller than the visual bounds, hence:
				let delta = safeAreaInsets.top + contentInset.top + contentInset.bottom + safeAreaInsets.bottom + contentSize.height - bounds.height
				contentOffset.y += max(0, min(addedHeight, delta))
				contentView.frame.origin.y += addedHeight

			case .bottom:
				footerView?.frame.origin.y = contentBottom
		}
	}


	private func clearContent() {
		contentSize.height = headerHeight + footerHeight
		contentOffset.y = -contentInset.top - safeAreaInsets.top
		contentView.frame.origin.y = -Self.MASTER_OFFSET + headerHeight
		headerView?.frame.origin.y = Self.MASTER_OFFSET - headerHeight
		footerView?.frame.origin.y = Self.MASTER_OFFSET
	}


	// MARK: - internal

	private var recyclePool = CommonPool()
	private var placeholders: [Placeholder] = [] // ordered by the `y` coordinate so that binarySearch() can be used on it

	// Living cells may exist only inside this range:
	private var currentWarmRange = 0..<0

	private var contentTop: CGFloat { placeholders.first?.top ?? Self.MASTER_OFFSET }
	private var contentBottom: CGFloat { placeholders.last?.bottom ?? Self.MASTER_OFFSET }
	private var headerHeight: CGFloat { headerView?.frame.height ?? 0 }
	private var footerHeight: CGFloat { footerView?.frame.height ?? 0 }


	private func doAddCells(edge: Edge, cellClass: UIView.Type, count: Int, animated: Bool) {
		switch edge {

			case .top:
				var newPlaceholders: [Placeholder] = []
				let totalHeight: CGFloat = estimatedCellHeight * CGFloat(count)
				var top: CGFloat = contentTop - totalHeight
				for _ in 0..<count {
					newPlaceholders.append(Placeholder(cellClass: cellClass, top: top, height: estimatedCellHeight, animated: animated))
					top += estimatedCellHeight
				}
				placeholders.insert(contentsOf: newPlaceholders, at: 0)

			case .bottom:
				for _ in 0..<count {
					placeholders.append(Placeholder(cellClass: cellClass, top: contentBottom, height: estimatedCellHeight, animated: animated))
				}
		}

		updateContentLayout(edgeHint: edge)
		validateVisibleRect()
	}


	private func doInsertCells(at index: Int, cellClass: UIView.Type, count: Int) {
		var top: CGFloat = placeholders.indices ~= (index - 1) ? placeholders[index - 1].bottom : contentTop
		for i in index..<(index + count) {
			placeholders.insert(Placeholder(cellClass: cellClass, top: top, height: estimatedCellHeight, animated: false), at: i)
			top += estimatedCellHeight
		}
		let totalHeight: CGFloat = estimatedCellHeight * CGFloat(count)
		for i in (index + count)..<placeholders.count {
			placeholders[i].moveBy(totalHeight)
		}
		updateContentLayout(edgeHint: .bottom)
		validateVisibleRect()
	}


	private func doRemoveCells(at index: Int, count: Int) {
		for i in index..<(index + count) {
			if let detachedCell = placeholders[i].detach() {
				recyclePool.enqueue(detachedCell)
			}
		}
		placeholders.removeSubrange(index..<(index + count))
		updateContentLayout(edgeHint: .bottom)
		validateVisibleRect()
	}


	private func doReplaceCell(at index: Int, cellClass: UIView.Type) {
		if let detachedCell = placeholders[index].detach() {
			recyclePool.enqueue(detachedCell)
		}
		placeholders[index].cellClass = cellClass
		updateContentLayout(edgeHint: .bottom)
		validateVisibleRect()
	}


	private func doReloadCell(at index: Int) {
		if let cell = placeholders[index].cell {
			reuseCell(cell, forIndex: index)
			let delta = placeholders[index].update()
			if delta != 0 {
				cellDidChangeHeightAt(index, delta: delta)
			}
		}
	}


	private func doReloadAll() {
		for i in currentWarmRange {
			doReloadCell(at: i)
		}
	}


	private func hotCellRange() -> Range<Int> {
		guard let contentView = contentView, !placeholders.isEmpty else {
			return 0..<0
		}
		// Certain number of screens should be kept "hot" in memory, e.g. for hotAreaFactor=1 half-screen above and half-screen below the visible area all objects should be available
		let rect = convert(bounds, to: contentView)
		let hotRect = rect.insetBy(dx: 0, dy: -(rect.height * hotAreaFactor / 2))
		let topHotIndex = max(0, placeholders.binarySearch(top: hotRect.minY) - 1)
		var i = topHotIndex
		repeat {
			i += 1
		} while i < placeholders.count && placeholders[i].top < hotRect.maxY
		return topHotIndex..<i
	}


	private func validateVisibleRect() {
		guard let contentView = contentView, rollingViewDelegate != nil else {
			return
		}

		// This can probably be optimized. Most of the time the change in contentOffset is insignificant and therefore the hot area indices don't change
		let hotRange = hotCellRange()

		for i in hotRange {
			// Make sure the hot cell already exists or create a new one otherwise
			if placeholders[i].cell == nil {
				let cell = recyclePool.dequeue(cellClass: placeholders[i].cellClass)
				reuseCell(cell, forIndex: i)
				let deltaHeight = placeholders[i].attach(cell: cell, toSuperview: contentView)
				if deltaHeight != 0 {
					// TODO: this can cause multiple recursive calls to validateVisibleRect()
					cellDidChangeHeightAt(i, delta: deltaHeight)
				}
			}
		}

		// Expand the hot area by warmCellCount more cells in both directions; everything beyond that should be removed and sent to the reuse pool
		let warmRange = max(0, hotRange.startIndex - warmCellCount / 2) ..< min(placeholders.count, hotRange.endIndex + warmCellCount / 2)

		if warmRange != currentWarmRange {
			for i in currentWarmRange {
				if !(warmRange ~= i), let detachedCell = placeholders[i].detach() {
					recyclePool.enqueue(detachedCell)
				}
			}
			currentWarmRange = warmRange
		}
	}


	private func cellDidChangeHeightAt(_ index: Int, delta: CGFloat) {
		precondition(delta != 0)
		if index == placeholders.count - 1 { // Last cell? Don't move anything
			updateContentLayout(edgeHint: .bottom)
		}
		else {
			for i in 0...index { // for the rest, move everything up, including the cell just created
				placeholders[i].moveBy(-delta)
			}
			updateContentLayout(edgeHint: .top)
		}
	}


	private func clearCells() {
		for placeholder in placeholders {
			placeholder.cell?.removeFromSuperview()
		}
		placeholders = []
		recyclePool.clear()
	}


	// MARK: - internal classes

	private class CommonPool {

		func register(cellClass: UIView.Type, create: @escaping () -> UIView) {
			dict[ObjectIdentifier(cellClass)] = Pool(create: create)
		}

		func preallocate(_ count: Int, cellClass: UIView.Type) {
			dict[ObjectIdentifier(cellClass)]!.preallocate(count)
		}

		func enqueue(_ element: UIView) {
			dict[ObjectIdentifier(type(of: element))]!.enqueue(element)
		}

		func dequeue(cellClass: UIView.Type) -> UIView {
			// A crash here means the class is not registered
			return dict[ObjectIdentifier(cellClass)]!.dequeueOrCreate()
		}

		func clear() {
			for key in dict.keys {
				dict[key]!.array.removeAll()
			}
		}

		private struct Pool {
			var create: () -> UIView
			var array: [UIView] = []

			mutating func preallocate(_ count: Int) {
				while array.count < count {
					array.append(create())
					RLOG("RollingView: PREALLOC")
				}
			}

			mutating func enqueue(_ element: UIView) {
				array.append(element)
				RLOG("RollingView: recycling cell")
			}

			mutating func dequeueOrCreate() -> UIView {
				if !array.isEmpty {
					RLOG("RollingView: reusing cell")
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
		var animated: Bool // animate the first appearance only

		var bottom: CGFloat {
			return top + height
		}

		init(cellClass: UIView.Type, top: CGFloat, height: CGFloat, animated: Bool) {
			self.cellClass = cellClass
			self.top = top
			self.height = height
			self.animated = animated
		}

		mutating func attach(cell: UIView, toSuperview superview: UIView) -> CGFloat {
			precondition(self.cell == nil)
			self.cell = cell
			cell.frame.origin.y = top
			let delta = cell.frame.size.height - height
			height = cell.frame.size.height
			superview.addSubview(cell)
			if animated {
				animated = false
				cell.alpha = 0
				UIView.animate(withDuration: 0.3, animations: { cell.alpha = 1 })
			}
			return delta
		}

		mutating func detach() -> UIView? {
			let temp = cell
			temp?.removeFromSuperview()
			cell = nil
			return temp
		}

		mutating func update() -> CGFloat {
			guard let cell = cell else {
				preconditionFailure()
			}
			let delta = cell.frame.size.height - height
			height = cell.frame.size.height
			return delta
		}

		func containsPoint(_ point: CGPoint) -> Bool {
			return point.y >= top && point.y <= top + height
		}

		mutating func moveBy(_ offset: CGFloat) {
			top += offset
			cell?.frame.origin.y = top
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
