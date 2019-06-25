//
//  CachingLoader.swift
//  ElevenLife
//
//  Created by Hovik Melikyan on 07/05/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


typealias CachingLoader<T: AnyObject> = CachingLoaderImpl<T> & CachingLoaderAbstract


struct CachingDictionary<K: AnyObject, T: AnyObject> {

	private var cache = NSCache<K, T>()

	init(capacity: Int) {
		cache.countLimit = capacity
	}

	subscript(key: K) -> T? {
		get {
			return cache.object(forKey: key)
		}
		set {
			if newValue == nil {
				cache.removeObject(forKey: key)
			}
			else {
				cache.setObject(newValue!, forKey: key)
			}
		}
	}

	func clear() {
		cache.removeAllObjects()
	}
}



private let DEFAULT_MEM_CACHE_CAPACITY = 50
private let CACHING_LOADER_ERROR_DOMAIN = "HMCachingLoaderError"


protocol CachingLoaderAbstract {
	var cacheFolderName: String { get }

	// Can return the object, e.g. UIImage, or the file path itself e.g. for media files that will be streamed directly from file. The reason the return type is not a generic is because Swift is still bad at overriding protocol generics in classes. Return nil if you want to indicate the file is damaged and should be deleted.
	func readFromCacheFile(path: String) -> Any?
}


class CachingLoaderImpl<T: AnyObject> {

	private var memCache: CachingDictionary<NSString, T> = CachingDictionary(capacity: DEFAULT_MEM_CACHE_CAPACITY)
	private var completions: [URL: [(T?, Error?) -> Void]] = [:]


	init() {
	}


	func request(url key: String, completion: @escaping (T?, Error?) -> Void) {
		// Available in the cache? Return immediately:
		if let result = memCache[key as NSString] {
			completion(result, nil)
			return
		}

		guard let url = URL(string: key) else {
			completion(nil, NSError(domain: CACHING_LOADER_ERROR_DOMAIN, code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(key)"]))
			return
		}

		// Queue requests to be called later at once, when the result becomes available; the first request triggers the download:

		if completions[url] == nil || completions[url]!.isEmpty {
			completions[url] = [completion]
			refresh(key: key, url: url)
		}
		else {
			completions[url]!.append(completion)
		}
	}


	func willRefresh(url key: String) -> Bool {
		if memCache[key as NSString] != nil {
			return false
		}
		guard let url = URL(string: key) else {
			return false
		}
		return FileManager.default.fileExists(atPath: cacheFilePathForURL(key: key, url: url))
	}


	// - - - PROTECTED

	private func refresh(key: String, url: URL) {
		// TODO: handle the file:/// scheme

		let cacheFilePath = cacheFilePathForURL(key: key, url: url)

		// Cache file exists? Resolve the queue immediately (currently only one deferred request will be in the queue in this case, but in the future we might support some more asynchronicity in how the file is loaded):
		if FileManager.default.fileExists(atPath: cacheFilePath) {
			refreshCompleted(key: key, url: url, cacheFilePath: cacheFilePath, error: nil)
		}

			// Otherwise start the async download:
		else {
			FileDownloader(url: url, progress: nil, completion: { (tempURL, error) in
				if let error = error {
					self.refreshCompleted(key: key, url: url, cacheFilePath: nil, error: error)
				}
				else {
					try! FileManager.default.moveItem(at: tempURL!, to: URL(fileURLWithPath: cacheFilePath))
					self.refreshCompleted(key: key, url: url, cacheFilePath: cacheFilePath, error: nil)
				}
			}).resume()
		}
	}


	private func refreshCompleted(key: String, url: URL, cacheFilePath: String?, error: Error?) {
		// Resolve the queue: call completion handlers accumulated so far:
		while completions[url] != nil && !completions[url]!.isEmpty {
			let completion = completions[url]!.removeFirst()
			if let cacheFilePath = cacheFilePath {
				refreshCompleted(key: key, cacheFilePath: cacheFilePath, completion: completion)
			}
			else {
				completion(nil, error)
			}
		}
		completions.removeValue(forKey: url)
	}


	private func refreshCompleted(key: String, cacheFilePath: String, completion: @escaping (T?, Error?) -> Void) {
		// Refresh ended successfully: allow the subclass to load the data (or do whatever transformation) that should be stored in the memory cache:
		if let result = (self as! CachingLoaderAbstract).readFromCacheFile(path: cacheFilePath) {
			memCache[key as NSString] = (result as! T)
			completion((result as! T), nil)
		}

			// The subclass transformation function returned nil: delete the file and signal an app error:
		else {
			try? FileManager.default.removeItem(atPath: cacheFilePath)
			completion(nil, NSError(domain: CACHING_LOADER_ERROR_DOMAIN, code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load cache file from disk"]))
		}
	}


	func cacheFilePathForURL(key: String, url: URL) -> String {
		return cacheSubdirectory(create: true) + "/" + key.toURLSafeHash(max: 32) + "." + url.pathExtension
	}


	func cacheSubdirectory(create: Bool) -> String {
		return FileManager.cacheDirectory(subDirectory: (self as! CachingLoaderAbstract).cacheFolderName, create: create)
	}


	func clearMemory() {
		memCache.clear()
	}


	func clearCache() {
		// NOTE: clearCache() should never be called from within a completion handler
		try? FileManager.default.removeItem(atPath: cacheSubdirectory(create: false))
	}


	func clear() {
		clearCache()
		clearMemory()
	}
}

