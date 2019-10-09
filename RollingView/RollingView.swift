//
//  RollingView.swift
//  RollingView
//
//  Created by Hovik Melikyan on 05/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


public protocol RollingViewDelegate: class {

	/// Set up a cell to be inserted into the RollingView object. This method is called either in response to your call to `addCells(...)` or when a cell is pulled from the recycle pool and needs to be set up for a given index position in the view. The class of the view is the same is when a cell was added using `addCells(...)` at a given position.
	func rollingView(_ rollingView: RollingView, reuseCell: UIView, forIndex index: Int)

	/// Try to load more data and create cells accordingly, possibly asynchronously. `completion` takes a boolean parameter that indicates whether more attempts should be made for a given `edge` in the future. Once `completion` returns false this delegate method will not be called again for a given `edge`. Optional.
	func rollingView(_ rollingView: RollingView, reached edge: RollingView.Edge, completion: @escaping (_ hasMore: Bool) -> Void)

	/// Cell at `index` has been tapped; optional. No visual changes take place in this case. If `cell` is not nil, it means the cell is visible on screen or is in the "hot" area, so you can make changes in it to reflect the gesture.
	func rollingView(_ rollingView: RollingView, didSelectCell cell: UIView?, atIndex index: Int)
}


public extension RollingViewDelegate {
	func rollingView(_ rollingView: RollingView, reached edge: RollingView.Edge, completion: @escaping (_ hasMore: Bool) -> Void) {
		completion(false)
	}

	func rollingView(_ rollingView: RollingView, didSelectCell: UIView?, atIndex index: Int) {
	}
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


	/// Set this if the height of cells is known and fixed; `nil` otherwse. RollingView can be slightly more efficient
	public var fixedCellHeight: CGFloat? {
		didSet { precondition(fixedCellHeight == nil || fixedCellHeight! >= 1) }
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
	public func register(cellClass: UIView.Type, create: @escaping () -> UIView) {
		recyclePool.register(cellClass: cellClass, create: create)
	}


	/// Tell RollingView that cells should be added either on top or to the bottom of the existing content. Your `rollingView(_:reuseCell:forIndex:)` implementation may be called for some or all of the added cells. Optionally the cells can fade-in animated.
	public func addCells(edge: Edge, cellClass: UIView.Type, count: Int, animated: Bool) {
		guard count > 0 else {
			return
		}

		if fixedCellHeight != nil {
			addFixedCells(to: edge, cellClass: cellClass, count: count, animated: animated)
		}
		else {
			let startUserIndex = startUserIndexForEdge(edge, newViewCount: count)
			let views = (startUserIndex..<(startUserIndex + count)).map { (index) -> UIView in
				return self.recyclePool.dequeue(forUserIndex: index, cellClass: cellClass, width: contentView.frame.width, reuseCell: reuseCell)
			}
			addCells(to: edge, cells: views, animated: animated)
		}
	}


	/// Tell RollingView that cells should be inserted starting at `index`. Your `rollingView(_:reuseCell:forIndex:)` implementation may be called for some or all of the inserted cells. Optionally the cells can fade-in animated.
	public func insertCells(at index: Int, cellClass: UIView.Type, count: Int, animated: Bool) {
		guard count > 0 else {
			return
		}
		if fixedCellHeight != nil {
			insertFixedCells(at: index - userIndexOffset, cellClass: cellClass, count: count, animated: animated)
		}
		else {
			let views = (index..<(index + count)).map { (index) -> UIView in
				return self.recyclePool.dequeue(forUserIndex: index, cellClass: cellClass, width: contentView.frame.width, reuseCell: reuseCell)
			}
			insertCells(at: index - userIndexOffset, cells: views, animated: animated)
		}
	}


	public func updateCell(at index: Int, cellClass: UIView.Type, animated: Bool) {
		let internalIndex = index - userIndexOffset
		if let detachedCell = placeholders[internalIndex].detach() {
			recyclePool.enqueue(detachedCell)
		}
		let newCell = recyclePool.dequeue(forUserIndex: index, cellClass: cellClass, width: contentView.frame.width, reuseCell: reuseCell)
		updateCell(at: internalIndex, cell: newCell, animated: animated)
	}


	/// Remove all cells and empty the recycle pool. Header and footer views remain intact.
	public func clear() {
		clearContent()
		clearCells()
		reachedEdge = [false, false]
	}


	/// Tell RollingView to call your delegate method `rollingView(_:reuseCell:forIndex:)` for each of the cells that are kept in the "hot" area, i.e. close or inside the visible area; this is similar to UITableView's `reloadData()`
	public func refreshHotCells() {
		for index in topHotIndex...bottomHotIndex {
			reloadCell(at: index + userIndexOffset)
		}
	}


	/// Tell RollingView to call your delegate method `rollingView(_:reuseCell:forIndex:)` on the cell at `index` if it's "hot", i.e. close or inside the visible area
	public func reloadCell(at index: Int) {
		if let cell = placeholders[index - userIndexOffset].cell {
			rollingViewDelegate?.rollingView(self, reuseCell: cell, forIndex: index)
		}
	}


	/// Returns a cell index for given a point on screen in RollingView's coordinate space.
	public func cellIndexFromPoint(_ point: CGPoint) -> Int? {
		let point = convert(point, to: contentView)
		let index = placeholders.binarySearch(top: point.y) - 1
		if index >= 0 && index < placeholders.count && placeholders[index].containsPoint(point) {
			return index + userIndexOffset
		}
		return nil
	}


	/// Returns a frame of a given cell index in RollingView's coordinates.
	public func frameOfCell(at index: Int) -> CGRect {
		let placeholder = placeholders[index - userIndexOffset]
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
		scrollRectToVisible(frameOfCell(at: index), animated: animated)
	}


	/// Checks if the scroller is within 20 points from the bottom; useful when deciding whether the view should be automatically scrolled to the bottom when adding new cells.
	public var isCloseToBottom: Bool {
		return isCloseToBottom(within: 20)
	}


	/// Header view, similar to UITableView's
	public var headerView: UIView? {
		willSet {
			if let headerView = headerView {
				headerView.removeFromSuperview()
				contentDidAddSpace(edge: .top, addedHeight: -headerView.frame.height, animated: false)
			}
		}
		didSet {
			if let headerView = headerView {
				headerView.frame.size.width = frame.width
				contentView.addSubview(headerView)
				contentDidAddSpace(edge: .top, addedHeight: headerView.frame.height, animated: false)
			}
		}
	}


	/// Footer view, similar to UITableView's
	public var footerView: UIView? {
		willSet {
			if let footerView = footerView {
				footerView.removeFromSuperview()
				contentDidAddSpace(edge: .bottom, addedHeight: -footerView.frame.height, animated: false)
			}
		}
		didSet {
			if let footerView = footerView {
				footerView.frame.size.width = frame.width
				contentView.addSubview(footerView)
				contentDidAddSpace(edge: .bottom, addedHeight: footerView.frame.height, animated: false)
			}
		}
	}


	// MARK: - internal: scroller

	private var contentView: UIView!
	private var firstLayout = true


	public override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}


	public required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}


	open override var backgroundColor: UIColor? {
		didSet { contentView?.backgroundColor = backgroundColor }
	}


	public override func layoutSubviews() {
		super.layoutSubviews()
		layout()
	}


	private func layout() {
		if firstLayout {
			firstLayout = false
			contentSize.width = frame.width
		}
	}


	private var reachedEdge = [false, false]

	public override var contentOffset: CGPoint {
		didSet {
			guard !firstLayout else {
				return
			}
			validateVisibleRect(animated: false)
			if !reachedEdge[Edge.top.rawValue] {
				let offset = contentOffset.y + contentInset.top + safeAreaInsets.top
				// Try to load more conent if the top of content is half a screen away
				if offset < frame.height / 2 {
					self.reachedEdge[Edge.top.rawValue] = true
					self.tryLoadMore(edge: .top)
				}
			}
			// Also try to load more content at the bottom
			if !reachedEdge[Edge.bottom.rawValue] && isCloseToBottom(within: frame.height / 2) {
				self.reachedEdge[Edge.bottom.rawValue] = true
				self.tryLoadMore(edge: .bottom)
			}
		}
	}


	private func reuseCell(_ reuseCell: UIView, forUserIndex index: Int) -> UIView {
		rollingViewDelegate!.rollingView(self, reuseCell: reuseCell, forIndex: index)
		return reuseCell
	}


	func isCloseToBottom(within pixels: CGFloat) -> Bool {
		return (contentSize.height + contentInset.bottom - (contentOffset.y + bounds.height)) < pixels
	}


	private func tryLoadMore(edge: Edge) {
		rollingViewDelegate?.rollingView(self, reached: edge) { (hasMore) in
			self.reachedEdge[edge.rawValue] = !hasMore
		}
	}


	// MARK: - internal: gestures


	private func setup() {
		addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap(_:))))
		setupContentView()
	}


	@objc private func onTap(_ sender: UITapGestureRecognizer) {
		if sender.state == .ended {
			if let userIndex = cellIndexFromPoint(sender.location(in: self)) {
				rollingViewDelegate?.rollingView(self, didSelectCell: placeholders[userIndex - userIndexOffset].cell, atIndex: userIndex)
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
		view.backgroundColor = backgroundColor
		insertSubview(view, at: 0)
		contentView = view
	}


	private func contentDidAddSpace(edge: Edge, addedHeight: CGFloat, animated: Bool) {
		layout()
		contentSize.height += addedHeight
		switch edge {
		case .top:
			UIView.animate(withDuration: animated ? Self.ANIMATION_DURATION : 0) {
				self.headerView?.frame.origin.y = self.contentTop - (self.headerView?.frame.height ?? 0)
				// The magic part of RollingView: when extra space is added on top, contentView and contentSize are adjusted here to create an illusion of infinite expansion:
				let delta = self.safeAreaInsets.top + self.contentInset.top + self.contentInset.bottom + self.safeAreaInsets.bottom + self.contentSize.height - self.bounds.height
				// The below is to ensure that when new content is added on top, the scroller doesn't move visually (though it does in terms of relative coordinates). It gets a bit trickier when the overall size of content is smaller than the visual bounds, hence:
				self.contentOffset.y += max(0, min(addedHeight, delta))
				self.contentView.frame.origin.y += addedHeight
			}
		case .bottom:
			UIView.animate(withDuration: animated ? Self.ANIMATION_DURATION : 0) {
				self.footerView?.frame.origin.y = self.contentBottom
			}
			break
		}
	}


	private func clearContent() {
		let headerHeight = headerView?.frame.height ?? 0
		let footerHeight = footerView?.frame.height ?? 0
		contentSize.height = headerHeight + footerHeight
		contentOffset.y = -contentInset.top - safeAreaInsets.top
		contentView.frame.origin.y = -Self.MASTER_OFFSET + headerHeight
		headerView?.frame.origin.y = Self.MASTER_OFFSET - headerHeight
		footerView?.frame.origin.y = Self.MASTER_OFFSET
	}


	// MARK: - internal: cell management

	private var recyclePool = CommonPool()
	private var placeholders: [Placeholder] = []	// ordered by the `y` coordinate so that binarySearch() can be used on it

	// Always negative or 0; from the user's perspective the cells added to the top have negative indices
	private var userIndexOffset = 0

	// Our "hot" area calculated in validateVisibleRect()
	private var topHotIndex = 0
	private var bottomHotIndex = 0


	private var contentTop: CGFloat {
		return placeholders.first?.top ?? Self.MASTER_OFFSET
	}


	private var contentBottom: CGFloat {
		return placeholders.last?.bottom ?? Self.MASTER_OFFSET
	}


	private func startUserIndexForEdge(_ edge: Edge, newViewCount count: Int) -> Int {
		switch edge {
		case .top:
			return userIndexOffset - count
		case .bottom:
			return userIndexOffset + placeholders.count
		}
	}


	private func addFixedCells(to edge: Edge, cellClass: UIView.Type, count: Int, animated: Bool) {
		guard let fixedCellHeight = fixedCellHeight else {
			preconditionFailure()
		}

		let totalHeight: CGFloat = fixedCellHeight * CGFloat(count)

		switch edge {

		case .top:
			userIndexOffset -= count
			var newCells: [Placeholder] = []
			var top: CGFloat = contentTop - totalHeight
			for _ in 0..<count {
				newCells.append(Placeholder(cellClass: cellClass, top: top, height: fixedCellHeight))
				top += fixedCellHeight
			}
			placeholders.insert(contentsOf: newCells, at: 0)

		case .bottom:
			for _ in 0..<count {
				placeholders.append(Placeholder(cellClass: cellClass, top: contentBottom, height: fixedCellHeight))
			}
		}

		validateVisibleRect(animated: animated)
		contentDidAddSpace(edge: edge, addedHeight: totalHeight, animated: animated)
	}


	private func addCells(to edge: Edge, cells: [UIView], animated: Bool) {
		var totalHeight: CGFloat = 0

		switch edge {

		case .top:
			userIndexOffset -= cells.count
			// We add the new cells reversed to the local temp array first, then insert into the global one in reverse order again; this way it's easier to calculate the coordinates
			var newCells: [Placeholder] = []
			var top: CGFloat = contentTop
			for cell in cells.reversed() {
				let cellHeight = cell.frame.height
				top -= cellHeight
				totalHeight += cellHeight
				cell.frame.origin.y = top

				// If the hot window is not at the top, then add a placeholder and discard the cell
				if topHotIndex > 0 {
					newCells.append(Placeholder(cellClass: type(of: cell), top: top, height: cellHeight))
					RLOG("RollingView: discarding unused cell")
				}
				else {
					newCells.append(Placeholder(cell: cell, addToSuperview: contentView, animated: animated))
				}
			}
			placeholders.insert(contentsOf: newCells.reversed(), at: 0)

		case .bottom:
			for cell in cells {
				let cellHeight = cell.frame.height
				totalHeight += cellHeight
				cell.frame.origin.y = contentBottom

				// If this is beyond our hot area, then add a placeholder and and discard the cell
				if bottomHotIndex < placeholders.count - 1 {
					placeholders.append(Placeholder(cellClass: type(of: cell), top: contentBottom, height: cellHeight))
					RLOG("RollingView: discarding unused cell")
				}
				else {
					placeholders.append(Placeholder(cell: cell, addToSuperview: contentView, animated: animated))
				}
			}
		}

		validateVisibleRect(animated: false) // false because this batch of cells was already animated above
		contentDidAddSpace(edge: edge, addedHeight: totalHeight, animated: animated)
	}


	private func insertFixedCells(at index: Int, cellClass: UIView.Type, count: Int, animated: Bool) {
		guard let fixedCellHeight = fixedCellHeight else {
			preconditionFailure()
		}
		let totalHeight: CGFloat = fixedCellHeight * CGFloat(count)
		var i = index
		var top: CGFloat = placeholders.indices.contains(i - 1) ? placeholders[i - 1].bottom : contentTop
		for _ in 0..<count {
			placeholders.insert(Placeholder(cellClass: cellClass, top: top, height: fixedCellHeight), at: i)
			top += fixedCellHeight
			i += 1
		}
		while i < placeholders.count {
			placeholders[i].moveBy(totalHeight, animated: animated)
			i += 1
		}
		validateVisibleRect(animated: animated)
		contentDidAddSpace(edge: .bottom, addedHeight: totalHeight, animated: animated)
	}


	private func insertCells(at index: Int, cells: [UIView], animated: Bool) {
		var totalHeight: CGFloat = 0
		var i = index
		let discard = i < topHotIndex || i > bottomHotIndex
		for cell in cells {
			let cellHeight = cell.frame.height
			totalHeight += cellHeight
			cell.frame.origin.y = placeholders.indices.contains(i - 1) ? placeholders[i - 1].bottom : contentTop
			if discard {
				placeholders.insert(Placeholder(cellClass: type(of: cell), top: cell.frame.origin.y, height: cellHeight), at: i)
				RLOG("RollingView: discarding unused cell")
			}
			else {
				placeholders.insert(Placeholder(cell: cell, addToSuperview: contentView, animated: animated), at: i)
			}
			i += 1
		}
		while i < placeholders.count {
			placeholders[i].moveBy(totalHeight, animated: animated)
			i += 1
		}
		validateVisibleRect(animated: false) // false because this batch of cells will already be animated in addCells()
		contentDidAddSpace(edge: .bottom, addedHeight: totalHeight, animated: animated)
	}



	private func updateCell(at index: Int, cell: UIView, animated: Bool) {
		let delta = cell.frame.height - placeholders[index].height
		if delta != 0 {
			placeholders[index].height = cell.frame.height
			for i in (index + 1)..<placeholders.count {
				placeholders[i].moveBy(delta, animated: animated)
			}
		}
		precondition(placeholders[index].cell == nil)
		let cellClass = type(of: cell)
		if cellClass != placeholders[index].cellClass {
			placeholders[index].cellClass = cellClass
		}
		recyclePool.enqueue(cell)
		validateVisibleRect(animated: animated)
		contentDidAddSpace(edge: .bottom, addedHeight: delta, animated: animated)
	}



	private func validateVisibleRect(animated: Bool) {
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
				let cell = recyclePool.dequeue(forUserIndex: index + userIndexOffset, cellClass: placeholders[index].cellClass, width: contentView.frame.width, reuseCell: reuseCell)
				placeholders[index].attach(cell: cell, toSuperview: contentView, animated: animated)
			}
			index += 1
		} while index < placeholders.count && placeholders[index].bottom < hotRect.maxY
		bottomHotIndex = index - 1

		// Expand the hot area by warmCellCount more cells in both directions; everything beyond that can be freed:
		index = topHotIndex - warmCellCount / 2
		while index >= 0, let detachedCell = placeholders[index].detach() {
			recyclePool.enqueue(detachedCell)
			index -= 1
		}

		index = bottomHotIndex + warmCellCount / 2
		while index < placeholders.count, let detachedCell = placeholders[index].detach() {
			recyclePool.enqueue(detachedCell)
			RLOG("RollingView: discarding at \(index + userIndexOffset)")
			index += 1
		}
	}


	private func clearCells() {
		for placeholder in placeholders {
			placeholder.cell?.removeFromSuperview()
		}
		placeholders = []
		recyclePool.clear()
		userIndexOffset = 0
		topHotIndex = 0
		bottomHotIndex = 0
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

		func dequeue(forUserIndex index: Int, cellClass: UIView.Type, width: CGFloat, reuseCell: (UIView, Int) -> UIView) -> UIView {
			let key = ObjectIdentifier(cellClass)
			precondition(dict[key] != nil, "RollingView cell class \(cellClass) not registered")
			let cell = dict[key]!.dequeueOrCreate()
			cell.frame.size.width = width
			return reuseCell(cell, index)
		}

		func clear() {
			for key in dict.keys {
				dict[key]!.array.removeAll()
			}
		}

		private struct Pool {
			var create: () -> UIView
			var array: [UIView] = []

			mutating func enqueue(_ element: UIView) {
				array.append(element)
				RLOG("RollingView: recycling cell, pool: \(array.count)")
			}

			mutating func dequeueOrCreate() -> UIView {
				if !array.isEmpty {
					RLOG("RollingView: reusing cell, pool: \(array.count - 1)")
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

		init(cell: UIView, addToSuperview superview: UIView, animated: Bool) {
			self.cell = cell
			self.cellClass = type(of: cell)
			self.top = cell.frame.minY
			self.height = cell.frame.height
			Self.add(cell: cell, to: superview, animated: animated)
		}

		mutating func attach(cell: UIView, toSuperview superview: UIView, animated: Bool) {
			precondition(self.cell == nil)
			self.cell = cell
			cell.frame.origin.y = top
			cell.frame.size.height = height
			Self.add(cell: cell, to: superview, animated: animated)
		}

		mutating func detach() -> UIView? {
			let temp = cell
			temp?.removeFromSuperview()
			cell = nil
			return temp
		}

		static func add(cell: UIView, to superview: UIView, animated: Bool) {
			cell.alpha = 0
			superview.addSubview(cell)
			UIView.animate(withDuration: animated ? ANIMATION_DURATION : 0) {
				cell.alpha = 1
			}
		}

		func containsPoint(_ point: CGPoint) -> Bool {
			return point.y >= top && point.y <= top + height
		}

		mutating func moveBy(_ offset: CGFloat, animated: Bool) {
			top += offset
			if let cell = cell {
				let top = self.top
				UIView.animate(withDuration: animated ? ANIMATION_DURATION : 0) {
					cell.frame.origin.y = top
				}
			}
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

