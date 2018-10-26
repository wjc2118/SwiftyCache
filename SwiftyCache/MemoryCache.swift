//
//  MemoryCache.swift
//  TEST
//
//  Created by Mac-os on 17/1/5.
//  Copyright © 2017年 risen. All rights reserved.
//

import UIKit

public final class MemoryCache {
    
    public init() {
        pthread_mutex_init(&_lock, nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(MemoryCache._appDidReceiveMemoryWarningNotification), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(MemoryCache._appDidEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        _trimRecursively()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        _list.removeAll()
        pthread_mutex_destroy(&_lock)
    }
    
    public var countLimit: Int = .max
    
    public var ageLimit: TimeInterval = .greatestFiniteMagnitude
    
    public var autoTrimInterval: TimeInterval = 5.0
    
    public var shouldRemoveAllOnMemoryWarning: Bool = true
    
    public var shouldRemoveAllWhenEnteringBackground: Bool = true
    
    public var totalCount: Int {
        pthread_mutex_lock(&_lock)
        defer { pthread_mutex_unlock(&_lock) }
        return _list._totalCount
    }
    
    public func contains(for key: String) -> Bool {
        pthread_mutex_lock(&_lock)
        defer { pthread_mutex_unlock(&_lock) }
        return _list._dict.keys.contains(key)
    }
    
    public func value(for key: String) -> Any? {
        pthread_mutex_lock(&_lock)
        defer { pthread_mutex_unlock(&_lock) }
        guard let node = _list._dict[key] else { return nil }
        node._time = CACurrentMediaTime()
        _list.bringToHead(node: node)
        return node._value
    }
    
    public func setValue(_ val: Any, for key: String) {
        pthread_mutex_lock(&_lock)
        defer { pthread_mutex_unlock(&_lock) }
        let now = CACurrentMediaTime()
        if let node = _list._dict[key] {
            node._time = now
            node._value = val
            _list.bringToHead(node: node)
        } else {
            let node = _Node()
            node._key = key
            node._value = val
            node._time = now
            _list.insertAtHead(node: node)
        }
        
        if _list._totalCount > countLimit {
            _ = _list.removeTailNode()
        }
    }
    
    public func removeValue(for key: String) {
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
    
    public func trimToCount(_ count: Int) {
        if count <= 0 {
            removeAll(); return
        }
        _trimToCount(count)
    }
    
    public func trimToAge(_ age: TimeInterval) {
        _trimToAge(age)
    }
    
    // MARK: - private
    
    private var _list = _List()
    
    private var _lock = pthread_mutex_t()
    
    private let _trimQueue = DispatchQueue(label: "_trimQueue")
    
    private func _trimRecursively() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + self.autoTrimInterval) { [weak self] in
            guard let `self` = self else { return }
            self._trimInBackground()
            self._trimRecursively()
        }
    }
    
    private func _trimInBackground() {
        _trimQueue.async {
            self._trimToCount(self.countLimit)
            self._trimToAge(self.ageLimit)
        }
    }
    
    private func _trimToCount(_ count: Int) {
        
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
        if shouldRemoveAllOnMemoryWarning {
            removeAll()
        }
    }
    
    @objc private func _appDidEnterBackgroundNotification() {
        if shouldRemoveAllWhenEnteringBackground {
            removeAll()
        }
    }
    
    func test() {
        
        var _node3 = _Node()
        var _node2 = _Node()
        
        for i in 0..<5 {
            let node = _Node()
            node._key = String(i)
            node._value = i
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
    var _value: Any!
    var _time: CFTimeInterval!
}

fileprivate class _List {
    var _head: _Node!
    var _tail: _Node!
    var _dict: [String: _Node] = [String: _Node]()
    var _totalCount: Int { return _dict.count }
}

fileprivate extension _List {
    
     func insertAtHead(node: _Node) {
        _dict.updateValue(node, forKey: node._key)
        
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
        
        node._prev?._next = node._next
        node._next?._prev = node._prev
        if _head === node { _head = node._next }
        if _tail === node { _tail = node._prev }
        
    }
    
     func removeTailNode() -> _Node? {
        if _tail == nil { return nil }
        let nodeToRemove = _tail!
        _dict.removeValue(forKey: nodeToRemove._key)
        
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
        _head = nil
        _tail = nil
        _dict = [String: _Node]()
    }
    
}


















