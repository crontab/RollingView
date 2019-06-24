//
//  ChatStructures.swift
//  RollingView
//
//  Created by Hovik Melikyan on 24/06/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit
import CoreLocation


class ChatroomContext: Codable {
	var attributes: VideoAttributes? // or availability info if videoId is empty
	var videoId: String?

	init(video: Video?) {
		self.videoId = video?.id
		self.attributes = video?.attributes
	}

	init(availability: VideoAttributes?) {
		self.attributes = availability
	}
}



class VideoAttributes: Codable {
	var tags: [String]
	var time: TimeTag?
	var places: [PlaceTag]

	var place: PlaceTag? { // for now we support only one place
		get { return places.first }
		set { places = newValue != nil ? [newValue!] : [] }
	}

	init() {
		tags = []
		time = nil
		places = []
	}

	init(from video: Video) {
		tags = video.tags
		time = video.time
		places = video.places
	}

	init(fromProfileTags tags: [String]) {
		self.tags = tags
		self.time = nil
		self.places = []
	}

	var isEmpty: Bool {
		return tags.isEmpty && time == nil && places.isEmpty
	}

	func impliedTimeZone(completion: @escaping (TimeZone?) -> Void) {
		if let place = place, let location = place.location {
			location.timezone { (timezone, error) in
				completion(timezone)
			}
		}
		else {
			completion(nil)
		}
	}
}



class Video: Codable {
	var id: String
	var userId: String
	var url: [String: String]?
	var tags: [String]
	var places: [PlaceTag]
	var time: TimeTag?
	var thumbnailUrl: String?
	var status: Int
	var originalLocation: Location? // returned by /map/view only

	var isComplete: Bool {
		return status == 1
	}

	var optimalUrl: String? {
		return url?[VideoType.H5.rawValue]
	}

	var attributes: VideoAttributes {
		get {
			return VideoAttributes(from: self)
		}
		set {
			tags = newValue.tags
			places = newValue.places
			time = newValue.time
		}
	}

	var place: PlaceTag? { // for now we support only one place
		get { return places.first }
		set { places = newValue != nil ? [newValue!] : [] }
	}

	var mapCoordinate: CLLocationCoordinate2D? {
		return place?.coordinate ?? originalLocation?.coordinate
	}
}



class TimeTag: Codable {
	var start: Date
	var end: Date?
	var recurrence: String?
	var timezone: String?

	init() {
		start = Date()
		timezone = TimeZone.current.identifier
	}

	func displayTitle(inTimeZone tz: TimeZone?) -> String {
		if let recurrenceAsShortList = recurrenceAsShortList {
			return recurrenceAsShortList + " " + start.toTimeWithTimezone(inTimeZone: tz)
		}
		else {
			return start.toShortHumanString(inTimeZone: tz)
		}
	}

	var recurrenceAsShortList: String? {
		return RRule.decodeWeekdays(from: recurrence)?.map({ $0.shortString }).joined(separator: ", ")
	}
}



class PlaceTag: Codable {
	var location: Location?
	var country: String?
	var locality: String?
	var address: String?
	var name: String?

	var coordinate: CLLocationCoordinate2D? {
		return location?.coordinate
	}

	var displayTitle: String {
		if let result = name ?? address ?? country {
			return result
		}
		if let location = location {
			return location.displayTitle
		}
		return "Unknown location"
	}
}



struct Location: Codable {
	var lat: Float64
	var lon: Float64

	var displayTitle: String {
		return String(format: "%.5f,%.5f", lat, lon)
	}

	init(from coordinate: CLLocationCoordinate2D) {
		lat = coordinate.latitude
		lon = coordinate.longitude
	}

	var coordinate: CLLocationCoordinate2D {
		return CLLocationCoordinate2D(latitude: lat, longitude: lon)
	}
}



extension Location {

	func timezone(completion: @escaping (TimeZone?, Error?) -> Void) {
		CLGeocoder().reverseGeocodeLocation(CLLocation.init(latitude: lat, longitude: lon)) { (placemarks, error) in
			if let placemarks = placemarks {
				completion(placemarks.first(where: { $0.timeZone != nil })?.timeZone, nil)
			}
			else {
				completion(nil, error)
			}
		}
	}
}



enum VideoType: String {
	case H5 = "H5"
	case L5 = "L5"
	case H4 = "H4"
	case L4 = "L4"
}




class Tag: Codable {
	var id: String
	var title: String?
	var color: String?
	var icon: String?
	var subtitle: String?
	var parentId: String?
	var sortOrder: Int?
	var postCount: Int?
	var liveCount: Int?
	var followCount: Int?

	static let ROOT_ID = "/"
	static let CUSTOM_TAG_ID = ".custom"
	static let PLACE_TAG_ID = ".place"
	static let TIME_TAG_ID = ".time"
	var _children: [Tag]? // resolved by the client; optional because otherwse JSONDecoder throws an error


	init(id: String, title: String? = nil, subtitle: String? = nil, color: String? = nil, icon: String? = nil) {
		self.id = id
		self.title = title
		self.subtitle = subtitle
		self.color = color
		self.icon = icon
	}
}



typealias TagDict = [String: Tag]


class PredefinedTags {

	static var defaultColor: UIColor = {
		return UIColor(red: 230 / 255, green: 73 / 255, blue: 128 / 255, alpha: 1)
	}()

	static var defaultIcon: UIImage = {
		return UIImage(named: "icon-hashtag")!
	}()

	// private static var customTagTemplate: Tag? // will be set by the next backend request
	static var placeTagTemplate = Tag(id: ".place", color: "225,225,225")
	static var timeTagTemplate = Tag(id: ".time", color: "225,225,225")


	private(set) static var all: TagDict = {
		return parseTags(tags: try! jsonDecoder.decode([Tag].self, from: try! Data(contentsOf: Bundle.main.url(forResource: "predefined-tags", withExtension: "json")!)))
	}()


	private static func parseTags(tags: [Tag]) -> TagDict {
		var dict: TagDict = [:]
		for tag in tags {
			dict[tag.id] = tag
		}
		dict[Tag.ROOT_ID] = Tag(id: Tag.ROOT_ID)
		for tag in tags {
			if tag.parentId == nil || tag.parentId!.isEmpty {
				tag.parentId = Tag.ROOT_ID
			}
			if let parent = dict[tag.parentId!] {
				if parent._children == nil {
					parent._children = [tag]
				}
				else {
					parent._children!.append(tag)
				}
			}
		}
		// PredefinedTags.customTagTemplate = dict[Tag.CUSTOM_TAG_ID] ?? PredefinedTags.customTagTemplate
		PredefinedTags.placeTagTemplate = dict[Tag.PLACE_TAG_ID] ?? PredefinedTags.placeTagTemplate
		PredefinedTags.timeTagTemplate = dict[Tag.TIME_TAG_ID] ?? PredefinedTags.timeTagTemplate
		return dict
	}


	static let jsonDecoder: JSONDecoder = {
		let result = JSONDecoder()
		result.keyDecodingStrategy = .convertFromSnakeCase
		result.dateDecodingStrategy = .formatted(DateFormatter.iso8601WithMS)
		return result
	}()
}
