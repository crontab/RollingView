//
//  TextBubbleFactory.swift
//  RollingView
//
//  Created by Hovik Melikyan on 09/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


typealias StringAttributes = [NSAttributedString.Key: Any]

private let BIG_CORNER: CGFloat = 20
private let SMALL_CORNER: CGFloat = 6

private let BIG_X_MARGIN: CGFloat = 100
private let SMALL_X_MARGIN: CGFloat = 10
private let STANDARD_MARGINS = UIEdgeInsets(top: 2, left: SMALL_X_MARGIN, bottom: 2, right: SMALL_X_MARGIN)

private let CONTEXT_MASTER_INSETS = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

private let VIDEO_THUMBNAIL_SIDE: CGFloat = 58
private let VIDEO_THUMBNAIL_PLAY_ICON_SIDE: CGFloat = 16
private let VIDEO_THUMBNAIL_SPACING: CGFloat = 8

private let TAG_HEIGHT: CGFloat = 22
private let TAG_DEFAULT_FONT_SIZE: CGFloat = 14
private let TAG_MAX_WIDTH: CGFloat = 230
private let TAG_HORIZ_PADDING: CGFloat = 7
private let TAG_CORNER_RADIUS: CGFloat = 5
private let TAG_VERT_SPACING: CGFloat = 5
private let TAG_HORIZ_SPACING: CGFloat = 4
private let TAG_ICON_SIDE: CGFloat = 14
private let TAG_ICON_SPACING: CGFloat = 4
private let TAG_SHOW_ICON = true



class BubbleLayer: CALayer {
	var text: String

	init(text: String) {
		self.text = text
		super.init()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}



class ContextBubbleFactory {

	func create(width: CGFloat, scale: CGFloat, isRightSide: Bool, title: String, attr: VideoAttributes, videoThumbnailUrl: String?) -> BubbleLayer {

		let host = BubbleLayer(text: attr.tags.joined(separator: ", "))
		host.frame = CGRect(x: 0, y: 0, width: width, height: CONTEXT_MASTER_INSETS.top + CONTEXT_MASTER_INSETS.bottom)

		// Master layer with a grey frame around it
		let master = CALayer()
		var margins = STANDARD_MARGINS
		if isRightSide {
			margins.left = BIG_X_MARGIN
		}
		else {
			margins.right = BIG_X_MARGIN
		}
		master.frame = host.bounds.inset(by: margins)
		master.borderColor = UIColor.init(white: 0.94, alpha: 1).cgColor
		master.borderWidth = 3
		master.masksToBounds = true
		master.cornerRadius = BIG_CORNER
		host.addSublayer(master)

		let innerWidth = master.frame.width - CONTEXT_MASTER_INSETS.left - CONTEXT_MASTER_INSETS.right
		var top = CONTEXT_MASTER_INSETS.top

		// Top label that explains what this is
		var titleAttr = StringAttributes()
		titleAttr[.font] = UIFont.systemFont(ofSize: 14)
		titleAttr[.foregroundColor] = UIColor(white: 0.3, alpha: 1)
		let topLabel = TextLayer(maxWidth: innerWidth, string: title, attributes: titleAttr)
		topLabel.frame.left = CONTEXT_MASTER_INSETS.left
		topLabel.frame.top = top
		master.addSublayer(topLabel)
		top = topLabel.frame.bottom

		// Video thumbnail
		var tagsLeftInset = CONTEXT_MASTER_INSETS.left
		let thumb = CALayer()
		if let videoThumbnailUrl = videoThumbnailUrl {
			thumb.frame = CGRect(x: tagsLeftInset, y: top + 11, width: VIDEO_THUMBNAIL_SIDE, height: VIDEO_THUMBNAIL_SIDE)
			thumb.contentsGravity = .resizeAspectFill
			thumb.allowsEdgeAntialiasing = true
			thumb.cornerRadius = VIDEO_THUMBNAIL_SIDE / 2
			thumb.masksToBounds = true
			CachingImageLoader.request(url: videoThumbnailUrl) { (image, error) in
				thumb.contents = image?.cgImage
			}
			master.addSublayer(thumb)
			tagsLeftInset = thumb.frame.right + VIDEO_THUMBNAIL_SPACING

			let playSide = VIDEO_THUMBNAIL_PLAY_ICON_SIDE
			let play = CALayer()
			play.frame = CGRect(x: (thumb.frame.width - playSide) / 2, y: (thumb.frame.height - playSide) / 2, width: playSide, height: playSide)
			play.contentsGravity = .resizeAspect
			play.allowsEdgeAntialiasing = true
			play.contents = UIImage(named: "icon-play-white-small")?.cgImage
			thumb.addSublayer(play)
		}

		// Tags, possibly indented if video thumbnail is present
		let tags = createTags(width: innerWidth - tagsLeftInset + CONTEXT_MASTER_INSETS.left, scale: scale, attr: attr)
		tags.frame.left = tagsLeftInset
		tags.frame.top = top + 11
		master.addSublayer(tags)

		master.frame.size.height = max(thumb.frame.bottom, tags.frame.bottom) + CONTEXT_MASTER_INSETS.bottom

		host.frame.size.height = master.frame.height + STANDARD_MARGINS.top + STANDARD_MARGINS.bottom
		return host
	}


	private func createTags(width: CGFloat, scale: CGFloat, attr: VideoAttributes) -> CALayer {
		let host = CALayer()
		host.frame = CGRect(x: 0, y: 0, width: width, height: 0)

		var sublayers: [CALayer] = []

		if let time = attr.time {
			sublayers.append(createTag(scale: scale, title: time.displayTitle(inTimeZone: nil), color: PredefinedTags.timeTagTemplate.uiColor, iconUrl: PredefinedTags.timeTagTemplate.icon))
		}

		if let place = attr.place {
			sublayers.append(createTag(scale: scale, title: place.displayTitle, color: PredefinedTags.placeTagTemplate.uiColor, iconUrl: PredefinedTags.placeTagTemplate.icon))
		}

		sublayers += attr.tags.map({ (tagId) -> CALayer in
			if let tag = PredefinedTags.all[tagId] {
				return createTag(scale: scale, title: tag.displayTitle, color: tag.uiColor, iconUrl: tag.icon)
			}
			else {
				return createTag(scale: scale, title: tagId, color: PredefinedTags.defaultColor, iconUrl: nil)
			}
		})

		host.sublayers = sublayers
		host.frame.size.height = layoutTagsVertically(scale: scale, width: width, layers: host.sublayers ?? [])

		return host
	}


	private func layoutTagsVertically(scale: CGFloat, width: CGFloat, layers: [CALayer]) -> CGFloat {
		var top: CGFloat = 0
		var left: CGFloat = 0
		for layer in layers {
			if left > 0 && left + layer.frame.width > width {
				left = 0
				top += scaledn(scale, TAG_HEIGHT + TAG_VERT_SPACING)
			}
			layer.frame.left = left
			layer.frame.top = top
			left += layer.frame.width + scaledn(scale, TAG_HORIZ_SPACING)
		}
		return layers.last?.frame.bottom ?? 0
	}


	private func createTag(scale: CGFloat, title: String, color: UIColor, iconUrl: String?) -> CALayer {
		let font = UIFont.systemFont(ofSize: scaleup(scale, TAG_DEFAULT_FONT_SIZE), weight: .bold)
		let titleWidth = min(ceil(title.size(withFont: font).width), TAG_MAX_WIDTH)

		let host = CALayer()
		host.frame = CGRect(x: 0, y: 0, width: titleWidth + 2 * scaleup(scale, TAG_HORIZ_PADDING), height: scaledn(scale, TAG_HEIGHT))
		host.cornerRadius = scaledn(scale, TAG_CORNER_RADIUS)
		host.backgroundColor = color.cgColor
		host.shadowColor = UIColor.black.cgColor
		host.shadowOpacity = 0.16
		host.shadowRadius = 2
		host.shadowOffset = CGSize.zero

		var attr = StringAttributes()
		attr[.font] = font
		attr[.foregroundColor] = (color.isDark ? UIColor.white : UIColor.black).cgColor
		let label = TextLayer(maxWidth: CGFloat.greatestFiniteMagnitude, string: title, attributes: attr)
		label.contentsScale = UIScreen.main.scale
		label.masksToBounds = true
		label.frame.left = scaledn(scale, TAG_HORIZ_PADDING)
		label.frame.top = (host.frame.height - label.frame.height) / 2 - scaledn(scale, 1)
		host.addSublayer(label)

		if TAG_SHOW_ICON, let iconUrl = iconUrl ?? PredefinedTags.customTagTemplate.icon {
			let side = scaledn(scale, TAG_ICON_SIDE)
			let icon = CALayer()
			icon.frame = CGRect(x: scaleup(scale, TAG_HORIZ_PADDING), y: (host.frame.size.height - side) / 2, width: side, height: side)
			icon.contentsGravity = .resizeAspect
			icon.allowsEdgeAntialiasing = true
			let delta = scaledn(scale, TAG_ICON_SIDE + TAG_ICON_SPACING)
			host.frame.size.width += delta
			label.frame.origin.x += delta
			host.addSublayer(icon)
			CachingImageLoader.request(url: iconUrl) { (image, error) in
				icon.contents = image?.cgImage
			}
		}

		return host
	}
}


private func scaleup(_ scale: CGFloat, _ value: CGFloat) -> CGFloat {
	return ceil(scale * value)
}


private func scaledn(_ scale: CGFloat, _ value: CGFloat) -> CGFloat {
	return floor(scale * value)
}



class LeftBubbleFactory: TextBubbleFactory {

	override init() {
		super.init()
		isRightSide = false
		font = UIFont.systemFont(ofSize: 16, weight: .medium)
		textColor = UIColor.black
		bubbleColor = UIColor(red:0.95, green:0.94, blue:0.94, alpha:1)
		margins.right = BIG_X_MARGIN
	}
}



class RightBubbleFactory: TextBubbleFactory {

	override init() {
		super.init()
		font = UIFont.systemFont(ofSize: 16, weight: .medium)
		textColor = UIColor.white
		bubbleColor = UIColor(red:0, green:0.53, blue:1, alpha:1)
		margins.left = BIG_X_MARGIN
	}
}



class TextBubbleFactory {

	fileprivate var isRightSide = true

	fileprivate var textAlignment: NSTextAlignment {
		get { return (attributes[.paragraphStyle] as! NSMutableParagraphStyle).alignment }
		set { (attributes[.paragraphStyle] as! NSMutableParagraphStyle).alignment = newValue }
	}

	fileprivate var font: UIFont? {
		get { return attributes[.font] as? UIFont }
		set { attributes[.font] = newValue }
	}

	fileprivate var textColor: UIColor? {
		get { return attributes[.foregroundColor] as? UIColor }
		set { attributes[.foregroundColor] = newValue }
	}

	fileprivate var insets = UIEdgeInsets(top: 9, left: 15, bottom: 9, right: 15)

	fileprivate var margins = STANDARD_MARGINS

	fileprivate var bubbleColor: UIColor? = UIColor(red: 50 / 255, green: 135 / 255, blue: 255 / 255, alpha: 1) // standard tint color
	fileprivate var backgroundColor = UIColor.white

	fileprivate var cornerRadius: CGFloat = BIG_CORNER


	private var attributes: StringAttributes = [.paragraphStyle: NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle]


	func create(width: CGFloat, string: String) -> BubbleLayer {
		let textLayer = TextLayer(maxWidth: width - insets.left - insets.right - margins.left - margins.right, string: string, attributes: attributes)
		textLayer.frame.left += insets.left
		textLayer.frame.top += insets.top

		let bubbleLayer = CALayer()
		bubbleLayer.frame.size = CGSize(width: textLayer.frame.right + insets.right, height: textLayer.frame.bottom + insets.bottom)
		bubbleLayer.backgroundColor = bubbleColor?.cgColor
		bubbleLayer.cornerRadius = min(cornerRadius, bubbleLayer.frame.height / 2)
		bubbleLayer.addSublayer(textLayer)
		bubbleLayer.frame.left += margins.left
		bubbleLayer.frame.top += margins.top
		if isRightSide {
			bubbleLayer.frame.left += width - margins.right - bubbleLayer.frame.right
		}

		let layer = BubbleLayer(text: string)
		layer.frame.size = CGSize(width: width, height: bubbleLayer.frame.bottom + margins.bottom)
		layer.backgroundColor = backgroundColor.cgColor
		layer.addSublayer(bubbleLayer)
		return layer
	}
}



private class TextLayer: CATextLayer {

	convenience init(maxWidth: CGFloat, string: String, attributes: StringAttributes) {
		self.init()
		self.contentsScale = UIScreen.main.scale
		let string = NSAttributedString(string: string, attributes: attributes)
		frame = string.boundingRect(with: CGSize(width: maxWidth, height: 10_000), options: [.usesFontLeading, .usesLineFragmentOrigin], context: nil)
		frame.size.width = ceil(frame.width)
		frame.size.height = ceil(frame.height)
		self.isWrapped = true
		switch (attributes[.paragraphStyle] as? NSParagraphStyle)?.alignment ?? .left {
		case .left: 	self.alignmentMode = .left
		case .right:	self.alignmentMode = .right
		case .center:	self.alignmentMode = .center
		case .justified: self.alignmentMode = .justified
		case .natural:	self.alignmentMode = .natural
		@unknown default:
			break
		}
		self.string = string
	}
}
