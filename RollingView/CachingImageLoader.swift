//
//  CachingImageLoader.swift
//  ElevenLife
//
//  Created by Hovik Melikyan on 07/05/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import UIKit


class CachingImageLoader: CachingLoader<UIImage> {

	private static var shared = CachingImageLoader()

	class func request(url: String, completion: @escaping (UIImage?, Error?) -> Void) {
		shared.request(url: url, completion: completion)
	}

	class func clearMemory() { shared.clearMemory() }

	class func clearCache() { shared.clearCache() }

	class func clear() { shared.clear()}


	// - - - PROTECTED

	private override init() {}

	var cacheFolderName: String = "Images"

	func readFromCacheFile(path: String) -> Any? {
		return UIImage(contentsOfFile: path)
	}
}
