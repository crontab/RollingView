# RollingView
**Two-way infinite scroller for messaging apps (Swift/iOS)**

The [RollingView.swift](https://github.com/crontab/RollingView/blob/master/RollingView/RollingView.swift) module is a self-contained module that you can copy into your project.

The idea of the infinite scroller is that you can add virtually unlimited number of UIView cells upward and downward: RollingView will adjust itself accordingly. It can also give you a chance to load more cells above or below the main content when the user scrolls closer to the top or the bottom, i.e. load chat history if available.

Similarly to UITableView, RollingView keeps only a limited number of cells in memory at any given time. It can decide to reuse cells at different indices.

A cell can be any UIView, however, keep in mind that all cells added to RollingView are always resized to the full width of the parent.

The RollingView class itself is based on UIScrollView and generally behaves like one.

And finally, RollingView is incredibly easy to use: you just need to implement two delegate methods to make it work:

* `rollingView(_:reuseCell:forIndex:)` - modify the supplied cell object to be shown at a given index. Note that indices can be negative for content added upward.
* `rollingView(_:reached:completion:)` - try to load more data and create cells accordingly, possibly asynchronously. `completion` takes a boolean parameter that indicates whether more attempt should be made for a given `edge` in the future.

And use the following public methods to add content:

* `register(cellClass:create:)` - register a cell class and its factory method `create()`; this should be called only once per each cell class.
* `addCells(edge:cellClass:count:)` - add content upward or downward, given a cell class and a number of cells to add. Your implementation of `rollingView(_:reuseCell:forIndex:)` will be called for setting up actual content in the cells.

The rest of the public methods and properties are documented in the source file [RollingView.swift](https://github.com/crontab/RollingView/blob/master/RollingView/RollingView.swift) .

Take a look at the demo app (load RollingVIew.xcodeproj) to have a better idea on how this works.

---
*Author: Hovik Melikyan*
