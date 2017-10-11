//
//  Cache.swift
//  TEST
//
//  Created by Mac-os on 17/1/9.
//  Copyright © 2017年 risen. All rights reserved.
//

import Foundation

public final class SwiftyCache {
    
    // MARK: - public
    
    public convenience init?(name: String) {
        guard let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else { return nil }
        self.init(path: cachePath + "/" + name)
    }
    
    public init?(path: String) {
        guard let dc = DiskCache.cache(path: path) else { return nil }
        _memoryCache = MemoryCache()
        _diskCache = dc
    }
    
    public func contains(for key: String) -> Bool {
        return _memoryCache.contains(for: key) || _diskCache.contains(for: key)
    }
    
    public func contains(for key: String, async: @escaping (String, Bool) -> ()) {
        if self._memoryCache.contains(for: key) {
            DispatchQueue.global().async {
                async(key, true)
            }
        } else {
            self._diskCache.contains(for: key, async: async)
        }
    }
    
    public func value(for key: String) -> Any? {
        if let val = _memoryCache.value(for: key) {
            return val
        }
        guard let val = _diskCache.value(for: key) else {
            return nil
        }
        _memoryCache.setValue(val, for: key)
        return val
    }
    
    public func value(for key: String, async: @escaping (String, Any?) -> ()) {
        if let obj = _memoryCache.value(for: key) {
            async(key, obj)
        } else {
            _diskCache.value(for: key, async: { (k, obj) in
                if obj != nil && self._memoryCache.value(for: k) == nil {
                    self._memoryCache.setValue(obj!, for: k)
                }
                async(k, obj)
            })
        }
    }
    
    public func setValue(_ val: Any, for key: String) {
        _memoryCache.setValue(val, for: key)
        _ = _diskCache.setValue(val, for: key)
    }
    
    public func setValue(_ val: Any, for key: String, async: @escaping (Bool) -> ()) {
        _memoryCache.setValue(val, for: key)
        _diskCache.setValue(val, for: key, async: async)
    }
    
    public func removeValue(for key: String) {
        _memoryCache.removeValue(for: key)
        _ = _diskCache.removeValue(for: key)
    }
    
    public func removeValue(for key: String, async: @escaping (String, Bool) -> ()) {
        _memoryCache.removeValue(for: key)
        _diskCache.removeValue(for: key, async: async)
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
    
    private lazy var _encoder = JSONEncoder()
    
    private lazy var _decoder = JSONDecoder()
    
}

// MARK: - Codable

public extension SwiftyCache {
    
    public func encode<V: Encodable>(_ val: V, for key: String, async: ((Bool) -> ())? = nil) {
        _memoryCache.setValue(val, for: key)
        guard let data = try? _encoder.encode(val) else { return }
        if let async = async {
            _diskCache.setData(data, for: key, async: async)
        } else {
            _ = _diskCache.setData(data, for: key)
        }
    }
    
    public func decode<V: Decodable>(for key: String, type: V.Type) -> V? {
        if let val = _memoryCache.value(for: key) as? V {
            return val
        }
        guard let data = _diskCache.data(for: key), let val = try? _decoder.decode(type, from: data) else { return nil }
        _memoryCache.setValue(val, for: key)
        return val
    }
    
    public func decode<V: Decodable>(for key: String, type: V.Type, async: @escaping (String, V?) -> ()) {
        if let val = _memoryCache.value(for: key) as? V {
            async(key, val)
            return
        }
        _diskCache.data(for: key) { (key, data) in
            guard let data = data, let val = try? self._decoder.decode(type, from: data) else {
                async(key, nil); return
            }
            self._memoryCache.setValue(val, for: key)
            async(key, val)
        }
    }
    
}






