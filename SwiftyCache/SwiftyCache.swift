//
//  Cache.swift
//  TEST
//
//  Created by Mac-os on 17/1/9.
//  Copyright © 2017年 wjc2118. All rights reserved.
//

import Foundation

public protocol Datable {
    func prepareArchive() -> [String: Any]
    init?(values: [String: Any]?)
}

public class SwiftyCache {
    
    // MARK: - public
    
    convenience init?(name: String) {
        guard let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else { return nil }
        let path = cachePath.appending("/" + name)
        self.init(path: path)
    }
    
    init?(path: String) {
        guard let dc = DiskCache.cache(path: path) else { return nil }
//        guard let dc = DiskCache(path: path) else { return nil }
        _memoryCache = MemoryCache()
        _diskCache = dc
    }
    
    public func containsObject(forkey key: String) -> Bool {
        return _memoryCache.containsObject(forkey: key) || _diskCache.containsObject(forkey: key)
    }
    
    public func containsObject(forkey key: String, async: @escaping (String, Bool) -> ()) {
        if self._memoryCache.containsObject(forkey: key) {
            DispatchQueue.global().async {
                async(key, true)
            }
        } else {
            self._diskCache.containsObject(forkey: key, async: async)
        }
    }
    
    public func object(forKey key: String, closure: (([String: Any]) -> (Any))? = nil) -> Any? {
        var obj = _memoryCache.object(forkey: key)
        if obj == nil {
            obj = _diskCache.object(forKey: key, closure: closure)
            if obj != nil {
                _memoryCache.setObject(obj!, forKey: key)
            }
        }
        return obj
    }
    
    public func object(forKey key: String, closure: (([String: Any]) -> (Any))? = nil, async: @escaping (String, Any?) -> ()) {
        if let obj = _memoryCache.object(forkey: key) {
            DispatchQueue.global().async {
                async(key, obj)
            }
        } else {
            _diskCache.object(forKey: key, closure: closure, async: { (k, obj) in
                if obj != nil && self._memoryCache.object(forkey: k) == nil {
                    self._memoryCache.setObject(obj!, forKey: k)
                }
                async(k, obj)
            })
        }
    }
    
    public func setObject(_ object: Any, forKey key: String, closure: ((Any) -> ([String: Any]))? = nil) {
        _memoryCache.setObject(object, forKey: key)
        _ = _diskCache.setObject(object, forKey: key, closure: closure)
    }
    
    public func setObject(_ object: Any, forKey key: String, closure: ((Any) -> ([String: Any]))? = nil, async: @escaping (Bool) -> ()) {
        _memoryCache.setObject(object, forKey: key)
        _diskCache.setObject(object, forKey: key, closure: closure, async: async)
    }
    
    public func removeObject(forKey key: String) {
        _memoryCache.removeObject(forKey: key)
        _ = _diskCache.removeObject(forKey: key)
    }
    
    public func removeObject(forKey key: String, async: @escaping (String, Bool) -> ()) {
        _memoryCache.removeObject(forKey: key)
        _diskCache.removeObject(forKey: key, async: async)
    }
    
    public func removeAll() {
        _memoryCache.removeAll()
        _ = _diskCache.removeAll()
    }
    
    public func removeAll(async: @escaping (Bool) -> ()) {
        _memoryCache.removeAll()
        _diskCache.removeAll(async: async)
    }
    
    public func removeAll(progress: @escaping (Int, Int) -> (), finish: @escaping (Bool) -> ()) {
        _memoryCache.removeAll()
        _diskCache.removeAll(progress: progress, finish: finish)
    }
    
    // MARK: - private
    
    private let _memoryCache: MemoryCache
    
    private let _diskCache: DiskCache
    
}

//protocol StructArchivable {
//    func prepareArchive() -> [String: Any]
//    init?(values: [String: Any]?)
//}
//
//struct Cache/*<T: StructArchivable>*/ {
//
//    private static var data: Data?
//
////    private static var structType: T?
//
//    static func setValue(_ value: StructArchivable) {
//        let dict = value.prepareArchive()
//        data = NSKeyedArchiver.archivedData(withRootObject: dict)
//    }
//
//
//    static func value<T: StructArchivable>(_ structType: T.Type) -> T? {
//        guard let data = data, let dict = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: Any]? else { return nil }
//        return structType.init(values: dict)
//    }
//}
