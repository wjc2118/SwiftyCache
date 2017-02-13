//
//  MemoryCache.swift
//  TEST
//
//  Created by Mac-os on 17/1/5.
//  Copyright © 2017年 risen. All rights reserved.
//

import Foundation
import UIKit

public class MemoryCache {
    
    init() {
        pthread_mutex_init(&_lock, nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(MemoryCache._appDidReceiveMemoryWarningNotification), name: .UIApplicationDidReceiveMemoryWarning, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(MemoryCache._appDidEnterBackgroundNotification), name: .UIApplicationDidEnterBackground, object: nil)
        
        //        _trimRecursively()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        _list.removeAll()
        pthread_mutex_destroy(&_lock)
    }
    
    public var countLimit: UInt = UInt.max
    
    public var ageLimit: TimeInterval = .greatestFiniteMagnitude
    
    public var autoTrimInterval: TimeInterval = 5.0
    
    public var shouldRemoveAllObjectsOnMemoryWarning: Bool = true
    
    public var shouldRemoveAllObjectsWhenEnteringBackground: Bool = true
    
    public var totalCount: UInt {
        
        pthread_mutex_lock(&_lock)
        defer { pthread_mutex_unlock(&_lock) }
        return _list._totalCount
    }
    
    public func containsObject(forkey key: String) -> Bool {
        pthread_mutex_lock(&_lock)
        defer { pthread_mutex_unlock(&_lock) }
        return _list._dict.keys.contains(key)
    }
    
    public func object(forkey key: String) -> Any? {
        pthread_mutex_lock(&_lock)
        defer { pthread_mutex_unlock(&_lock) }
        guard let node = _list._dict[key] else { return nil }
        node._time = CACurrentMediaTime()
        _list.bringToHead(node: node)
        return node._object
    }
    
    public func setObject(_ object: Any, forKey key: String) {
        pthread_mutex_lock(&_lock)
        defer { pthread_mutex_unlock(&_lock) }
        let now = CACurrentMediaTime()
        if let node = _list._dict[key] {
            node._time = now
            node._object = object
            _list.bringToHead(node: node)
        } else {
            let node = _Node()
            node._key = key
            node._object = object
            node._time = now
            _list.insertAtHead(node: node)
        }
        
        if _list._totalCount > countLimit {
            _ = _list.removeTailNode()
        }
    }
    
    public func removeObject(forKey key: String) {
        pthread_mutex_lock(&_lock)
        defer { pthread_mutex_unlock(&_lock) }
        guard let node = _list._dict[key] else { return }
        _list.remove(node: node)
    }
    
    public func removeAll() {
        pthread_mutex_lock(&_lock)
        defer { pthread_mutex_unlock(&_lock) }
        _list.removeAll()
    }
    
    public func trimToCount(_ count: UInt) {
        if count == 0 {
            removeAll(); return
        }
        _trimToCount(count)
    }
    
    public func trimToAge(_ age: TimeInterval) {
        _trimToAge(age)
    }
    
    // MARK: - private
    
    private func _lock(closure: () -> ()) {
        pthread_mutex_lock(&self._lock)
        defer { pthread_mutex_unlock(&self._lock) }
        closure()
    }
    
    private var _list: _List = _List()
    
    private var _lock: pthread_mutex_t = pthread_mutex_t()
    
    private let _trimQueue: DispatchQueue = DispatchQueue(label: "_trimQueue")
    
    private func _trimRecursively() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + self.autoTrimInterval) { [weak self] in
            self?._trimInBackground()
            self?._trimRecursively()
        }
    }
    
    private func _trimInBackground() {
        _trimQueue.async {
            self._trimToCount(self.countLimit)
            self._trimToAge(self.ageLimit)
        }
    }
    
    private func _trimToCount(_ count: UInt) {
        
        var isFinished = false
        
        pthread_mutex_lock(&_lock)
        if count == 0 {
            removeAll()
            isFinished = true
        } else if _list._totalCount <= count {
            isFinished = true
        }
        pthread_mutex_unlock(&_lock)
        if isFinished { return }
        
        while !isFinished {
            if pthread_mutex_trylock(&_lock) == 0 {
                if _list._totalCount > count {
                    _ = _list.removeTailNode()
                } else {
                    isFinished = true
                }
                pthread_mutex_unlock(&_lock)
            } else {
                usleep(1000 * 10)
            }
        }
    }
    
    private func _trimToAge(_ age: TimeInterval) {
        var isFinished = false
        let now = CACurrentMediaTime()
        pthread_mutex_lock(&_lock)
        if age <= 0.0 {
            removeAll()
            isFinished = true
        } else if _list._tail == nil || now - _list._tail._time < age {
            isFinished = true
        }
        pthread_mutex_unlock(&_lock)
        if isFinished { return }
        
        while !isFinished {
            if pthread_mutex_trylock(&_lock) == 0 {
                if _list._tail != nil && now - _list._tail._time > age {
                    _ = _list.removeTailNode()
                } else {
                    isFinished = true
                }
            } else {
                usleep(1000 * 10)
            }
        }
    }
    
    @objc private func _appDidReceiveMemoryWarningNotification() {
        print("_appDidReceiveMemoryWarningNotification")
        if shouldRemoveAllObjectsOnMemoryWarning {
            removeAll()
        }
    }
    
    @objc private func _appDidEnterBackgroundNotification() {
        if shouldRemoveAllObjectsWhenEnteringBackground {
            removeAll()
        }
    }
    
    func test() {
        
        var _node3 = _Node()
        var _node2 = _Node()
        
//        print(_list._head._key, _list._tail._key)
        for i in 0..<5 {
            let node = _Node()
            node._key = String(i)
            node._object = i
            node._time = CACurrentMediaTime()
            _list.insertAtHead(node: node)
            if i == 3 {
                _node3 = node
            }
            if i == 2 {
                _node2 = node
            }
        }
        print(_list._head._key, _list._tail._key)
        _list.remove(node: _node2)
        print(_list._head._key, _list._tail._key)
        _list.bringToHead(node: _node3)
        print(_list._head._key, _list._tail._key)
        _ = _list.removeTailNode()
        print(_list._head._key, _list._tail._key)
        
        func prinkey(node: _Node?) {
            if node != nil {
                print(node!._key)
                prinkey(node: node!._prev)
            } else {
                return
            }
        }
        
        prinkey(node: _list._tail)
        
    }
    
}

fileprivate class _Node {
    weak var _prev: _Node?
    weak var _next: _Node?
    var _key: String!
    var _object: Any!
    var _time: CFTimeInterval!
}

fileprivate class _List {
    var _head: _Node!
    var _tail: _Node!
    var _dict: [String: _Node] = [String: _Node]()
    var _totalCount: UInt = 0
}

fileprivate extension _List {
    
     func insertAtHead(node: _Node) {
        _dict.updateValue(node, forKey: node._key)
        _totalCount += 1
        if _head == nil {
            _head = node
            _tail = node
            node._prev = nil
            node._next = nil
        } else {
            _head._prev = node
            node._next = _head
            node._prev = nil
            _head = node
        }
    }
    
     func bringToHead(node: _Node) {
        if _head === node { return }
        
        if _tail === node {
            _tail = node._prev
            _tail._next = nil
        } else {
            node._prev?._next = node._next
            node._next?._prev = node._prev
        }
        node._next = _head
        node._prev = nil
        _head._prev = node
        _head = node
    }
    
     func remove(node: _Node) {
        _dict.removeValue(forKey: node._key)
        _totalCount -= 1
        
        node._prev?._next = node._next
        node._next?._prev = node._prev
        if _head === node { _head = node._next }
        if _tail === node { _tail = node._prev }
        
    }
    
     func removeTailNode() -> _Node? {
        if _tail == nil { return nil }
        let nodeToRemove = _tail!
        _dict.removeValue(forKey: nodeToRemove._key)
        _totalCount -= 1
        
        if _head === _tail {
            _head = nil
            _tail = nil
        } else {
            _tail = _tail._prev
            _tail._next = nil
        }
        
        return nodeToRemove
    }
    
     func removeAll() {
        _totalCount = 0
        _head = nil
        _tail = nil
        
        _dict = [String: _Node]()
    }
    
}


















