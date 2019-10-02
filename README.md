# RollingView
**Two-way infinite scroller for messaging apps (Swift/iOS)**

The [RollingView.swift](https://github.com/crontab/RollingView/blob/master/RollingView/RollingView.swift) module is a self-contained module that you can copy into your project. The demo app can be a good starting point for your chat app.

The idea of the infinite scroller is that you can add virtually unlimited number of UIView cells above or below: RollingView will adjust itself accordingly. It can also give you a chance to load more cells above the main content when the user scrolls closer to the top, i.e. load chat history if available.

Similarly to UITableView, RollingView keeps only a limited number of cells in memory at any given time. Cells can be reused at different indices.

Cells can be any UIView, however, keep in mind that all cells added to the scroller are always resized to the full width of the parent RollingView. The RollingView itself is based on UIScrollView and generally behaves like one.

RollingView is incredibly easy to use: you just need to implement two protocol methods:

* `rollingView(_:reuseCell:forIndex:)` - modify the supplied cell object to be shown at a given index. Note that indices can be negative for content added above.
* `rollingViewCanAddCellsAbove(_:completion:)` - try to load more (historical) content and call `completion(true)` if you think there may be more content or `completion(false)` if the user reached the end, i.e. this method won't be called again.

And use the following public methods to add content:

* `register(cellClass:create:)` - register a cell class and its factory method `create()`; this should be called only once per each cell class.
* `addCells(edge:cellClass:count:)` - add content above or below, given the cell class and a number of cells to add. Your implementation of `rollingView(_:reuseCell:forIndex:)` will be called for setting up actual content in the cells.
* `var bottomInset: CGFloat` - modify the RollingView's bottom inset: can be used when the keyboard pops up.

Take a look at the demo app (RollingVIew.xcodeproj) to have a better idea on how this works.
