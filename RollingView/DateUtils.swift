//
//  DateUtilities.swift
//  ElevenLife
//
//  Created by Hovik Melikyan on 28/05/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


// System order of Gregorian weekdays; the actual order depends on Calendar.firstWeekday
enum WeekdayCode: Int {
	case Sunday = 1
	case Monday = 2
	case Tuesday = 3
	case Wednesday = 4
	case Thursday = 5
	case Friday = 6
	case Saturday = 7

	init(index: Int) {
		self.init(rawValue: (max(0, min(6, index)) + Calendar.current.firstWeekday - 1) % 7 + 1)!
	}

	var string: String {
		return Calendar.current.weekdaySymbols[rawValue - 1]
	}

	var shortString: String {
		return Calendar.current.shortWeekdaySymbols[rawValue - 1]
	}
}


extension DateFormatter {

	static let iso8601WithMS: DateFormatter = {
		let dateFmt = DateFormatter()
		dateFmt.calendar = Calendar(identifier: .iso8601)
		dateFmt.locale = Locale(identifier: "en_US_POSIX")
		dateFmt.timeZone = TimeZone(secondsFromGMT: 0)
		dateFmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
		return dateFmt
	}()


	static let shortHuman: DateFormatter = {
		let dateFmt = DateFormatter()
		dateFmt.timeZone = TimeZone.current
		dateFmt.dateFormat = "EEE, MMM d  HH:mm"
		return dateFmt
	}()


	static let veryShortHuman: DateFormatter = {
		let dateFmt = DateFormatter()
		dateFmt.timeZone = TimeZone.current
		dateFmt.dateFormat = "MMM d, HH:mm"
		return dateFmt
	}()


	class func shortHuman(inTimeZone tz: TimeZone?) -> DateFormatter {
		if tz == nil || tz == TimeZone.current {
			return shortHuman
		}
		else {
			let dateFmt = DateFormatter()
			dateFmt.timeZone = tz
			dateFmt.dateFormat = "EEE, MMM d  HH:mm"
			return dateFmt
		}
	}

	class func timeOnly(inTimeZone tz: TimeZone?) -> DateFormatter {
		let dateFmt = DateFormatter()
		dateFmt.timeZone = tz ?? TimeZone.current
		dateFmt.dateFormat = "HH:mm"
		return dateFmt
	}
}



extension Date {

	func toShortHumanString(inTimeZone tz: TimeZone? = nil) -> String { // for tags
		return DateFormatter.shortHuman(inTimeZone: tz).string(from: self)
	}

	func toVeryShortHumanString() -> String { // for messages
		return DateFormatter.veryShortHuman.string(from: self)
	}

	func toTimeWithTimezone(inTimeZone tz: TimeZone? = nil) -> String {
		return DateFormatter.timeOnly(inTimeZone: tz).string(from: self)
	}
}



class RRule {

	// Limited implementation of the RRULE format that supports only weekday recurrance

	var weekdays: [WeekdayCode]?

	private static let weekdayNames: [Substring] = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"] // should be the same order as WeekdayCode


	class func decodeWeekdays(from string: String?) -> [WeekdayCode]? {
		return string == nil ? nil : RRule(from: string!)?.weekdays
	}


	class func encode(withWeekdayCodes codes: [WeekdayCode]?) -> String? {
		return (codes?.isEmpty ?? true) ? nil :
			"FREQ=WEEKLY;BYDAY=" + codes!.map({ RRule.weekdayNames[$0.rawValue - 1] }).joined(separator: ",")
	}


	private init() {
	}

	private init?(from string: String) {
		if let dict = RRule.asKeyValuePairs(string: string) {
			if dict["FREQ"] == "WEEKLY", let byDay = dict["BYDAY"] {
				for weekdayName in byDay.split(separator: ",") {
					if let index = RRule.weekdayNames.firstIndex(of: weekdayName) {
						if weekdays == nil {
							weekdays = []
						}
						weekdays!.append(WeekdayCode(rawValue: index + 1)!)
					}
				}
				return // success
			}
		}
		return nil
	}

	private class func asKeyValuePairs(string: String) -> [Substring: Substring]? {
		var result: [Substring: Substring] = [:]
		for item in string.split(separator: ";") {
			let kv = item.split(separator: "=", maxSplits: 1)
			if kv.count != 2 {
				return nil
			}
			result[kv[0]] = kv[1]
		}
		return result
	}
}

