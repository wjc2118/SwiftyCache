//
//  DiskCache.swift
//  TEST
//
//  Created by Mac-os on 17/1/9.
//  Copyright © 2017年 risen. All rights reserved.
//

import Foundation
import UIKit

public class DiskCache {
    
    // MARK: - public
    
    public static func cache(path: String, inlineThreshold: UInt = 1024 * 20) -> DiskCache? {
        if let global = _globalInstances[path] {
            return global
        }
        let instance = DiskCache(path: path, inlineThreshold: inlineThreshold)
        
        if instance != nil {
            _globalInstances[path] = instance!
        }
        return instance
        
    }
    
    public init?(path: String, inlineThreshold: UInt = 1024 * 20) {
        
        guard let storager = Storager(path: path) else { return nil }
        _storager = storager
        self.path = path
        self.inlineThreshold = inlineThreshold
        
        _trimRecursively()
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public let path: String
    
    public let inlineThreshold: UInt
    
    public let costLimit: UInt = UInt.max
    
    public let countLimit: UInt = UInt.max
    
    public let ageLimit: TimeInterval = .greatestFiniteMagnitude
    
    public let freeDiskSpaceLimit: UInt = 0
    
    public let autoTrimInterval: TimeInterval = 60
    
    public var totalCost: Int {
        _lock()
        let c = _storager.itemsSize()
        _unlock()
        return c
    }
    
    public var totalCount: Int {
        _lock()
        let c = _storager.itemsCount()
        _unlock()
        return c
    }
    
    public func containsObject(forkey key: String) -> Bool {
        _lock()
        let contains = _storager.itemExists(forKey: key)
        _unlock()
        return contains
    }
    
    public func containsObject(forkey key: String, async: @escaping (String, Bool) -> ()) {
        _queue.async { [weak self] in
            let c = self?.containsObject(forkey: key) ?? false
            async(key, c)
        }
    }
    
    public func object(forKey key: String, closure: (([String: Any]) -> (Any))? = nil) -> Any? {
        _lock()
        let item = _storager.item(forKey: key)
        _unlock()
        guard let value = item?.value else { return nil }
        
        guard var any = NSKeyedUnarchiver.unarchiveObject(with: value) else { return nil }
        if let closure = closure, let dic = any as? [String: Any] {
            any = closure(dic)
        }
        return any
    }
    
    public func object(forKey key: String, closure: (([String: Any]) -> (Any))? = nil, async: @escaping (String, Any?) -> ()) {
        _queue.async { [weak self] in
            let obj = self?.object(forKey: key, closure: closure)
            async(key, obj)
        }
    }
    
    public func setObject(_ object: Any, forKey key: String, closure: ((Any) -> ([String: Any]))? = nil) -> Bool {
        
        var toData = object
        if let closure = closure {
            toData = closure(object)
        }
        let data = NSKeyedArchiver.archivedData(withRootObject: toData)
        
        let filename = UInt(data.count) > inlineThreshold ? _filename(forKey: key) : nil
        
        _lock()
        let suc = _storager.saveItem(key: key, value: data, filename: filename)
        _unlock()
        return suc 
    }
    
    public func setObject(_ object: Any, forKey key: String, closure: ((Any) -> ([String: Any]))? = nil, async: @escaping (Bool) -> ()) {
        _queue.async { [weak self] in
            async(self?.setObject(object, forKey: key, closure: closure) ?? false)
        }
    }
    
    public func removeObject(forKey key: String) -> Bool {
        _lock()
        let suc = _storager.removeItem(key: key)
        _unlock()
        return suc
    }
    
    public func removeObject(forKey key: String, async: @escaping (String, Bool) -> ()) {
        _queue.async { [weak self] in
            async(key, self?._storager.removeItem(key: key) ?? false)
        }
    }
    
    public func removeAll() -> Bool {
        _lock()
        let suc = _storager.removeAllItems()
        _unlock()
        return suc
    }
    
    public func removeAll(async: @escaping (Bool) -> ()) {
        _queue.async { [weak self] in
            async(self?.removeAll() ?? false)
        }
    }
    
    public func removeAll(progress: @escaping (Int, Int) -> (), finish: @escaping (Bool) -> ()) {
        _queue.async { [weak self] in
            self?._lock()
            self?._storager.removeAllItems(progress: progress, finish: finish)
            self?._unlock()
        }
    }
    
    public func totalCost(_ async: @escaping (Int) -> ()) {
        _queue.async { [weak self] in
            async(self?.totalCost ?? 0)
        }
    }
    
    public func totalCount(_ async: @escaping (Int) -> ()) {
        _queue.async { [weak self] in
            async(self?.totalCount ?? 0)
        }
    }
    
    public func trimTo(cost: UInt) {
        _lock()
        _trimTo(cost: cost)
        _unlock()
    }
    
    public func trimTo(cost: UInt, async: @escaping () -> ()) {
        _queue.async { [weak self] in
            self?.trimTo(cost: cost)
            async()
        }
    }
    
    public func trimTo(count: UInt) {
        _lock()
        _trimTo(count: count)
        _unlock()
    }
    
    public func trimTo(count: UInt, async: @escaping () -> ()) {
        _queue.async { [weak self] in
            self?.trimTo(count: count)
            async()
        }
    }
    
    public func trimTo(age: TimeInterval) {
        _lock()
        _trimTo(age: age)
        _unlock()
    }
    
    public func trimTo(age: TimeInterval, async: @escaping () -> ()) {
        _queue.async {
            self.trimTo(age: age)
            async()
        }
    }
    
    // MARK: - private
    
    private static var _globalInstances = [String: DiskCache]()
    
    private let _storager: Storager
    
    private let __lock: DispatchSemaphore = DispatchSemaphore(value: 1)
    
    private let _queue: DispatchQueue = DispatchQueue(label: "DiskCacheQueue", attributes: .concurrent)
    
    private var _diskFreeSize: UInt {
        var attrs: [FileAttributeKey : Any]
        do {
            try attrs = FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        } catch {
            print(error)
            return 0
        }
        return attrs[.systemFreeSize] as? UInt ?? 0
    }
    
    private func _lock() {
        _ = __lock.wait(wallTimeout: .distantFuture)
    }
    
    private func _unlock() {
        __lock.signal()
    }
    
    private func _trimRecursively() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + autoTrimInterval) { [weak self] in
            self?._trimInBackground()
            self?._trimRecursively()
        }
    }
    
    private func _trimInBackground() {
        _queue.async { [weak self] in
            self?._lock()
            self?._trimTo(cost: self?.costLimit ?? UInt.max)
            self?._trimTo(count: self?.countLimit ?? UInt.max)
            self?._trimTo(age: self?.ageLimit ?? .greatestFiniteMagnitude)
            self?._trimTo(freeDiskSpace: self?.freeDiskSpaceLimit ?? 0)
            self?._unlock()
        }
    }
    
    private func _trimTo(cost: UInt) {
        if cost >= UInt(Int.max) { return }
        _ = _storager.removeItemsToFit(size: Int(cost))
    }
    
    private func _trimTo(count: UInt) {
        if count >= UInt(Int.max) { return }
        _ = _storager.removeItemsToFit(count: Int(count))
    }
    
    private func _trimTo(age: TimeInterval) {
        if age <= 0.0 {
            _ = _storager.removeAllItems()
            return
        }
        let timeStamp = Double(time(nil))
        if timeStamp <= age {
            return
        }
        let timeLimit = timeStamp - age
        _ = _storager.removeItemsEarlierThan(time: Int(timeLimit))
    }
    
    private func _trimTo(freeDiskSpace: UInt) {
        if freeDiskSpace == 0 { return }
        let totalSize = _storager.itemsSize()
        if totalSize <= 0 { return }
        let diskFreeSize = _diskFreeSize
        if diskFreeSize == 0 { return }
        if freeDiskSpace <= diskFreeSize { return }
        let toTrim = freeDiskSpace - diskFreeSize  //  toTrim > 0
        let limit = UInt(totalSize) - toTrim
        _trimTo(cost: limit)
    }
    
    private func _filename(forKey key: String) -> String {
        return key.md5
    }
    
}

fileprivate extension String {
    
    fileprivate var md5: String {
        
        let cStr = self.cString(using: .utf8)
        let strLen = CC_LONG(self.lengthOfBytes(using: .utf8))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen);
        
        CC_MD5(cStr!, strLen, result);
        
        let hash = NSMutableString();
        for i in 0 ..< digestLen {
            hash.appendFormat("%02x", result[i]);
        }
        result.deinitialize();
        
        return String(format: hash as String)
        
    }
    
}

fileprivate class Item {
    let key: String
    var value: Data?
    let filename: String?
    let size: Int
    let modTime: Int
    let accessTime: Int
    
    init(key: String, value: Data?, filename: String?, size: Int, modTime: Int, accessTime: Int) {
        self.key = key
        self.value = value
        self.filename = filename
        self.size = size
        self.modTime = modTime
        self.accessTime = accessTime
    }
}

fileprivate class Storager {
    
    typealias sqlite3_stmt = OpaquePointer
    typealias sqlite3 = OpaquePointer
    
    init?(path: String) {
        _path = path
        _dbPath = path + "/manifest.sqlite"
        _dataPath = path.appending("/DATA")
        _trashPath = path.appending("/TRASH")
        
        do {
            try FileManager.default.createDirectory(atPath: self._path, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(atPath: self._dataPath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(atPath: self._trashPath, withIntermediateDirectories: true)
        } catch {
            print(error)
            return nil
        }
        
        if !_dbOpen() || !_dbInitialize() {
            _ = _dbClose()
            _reset()
            if !_dbOpen() || !_dbInitialize() {
                _ = _dbClose()
                return nil
            }
        }
        
        _fileEmptyTrashInBackground()
    }
    
    deinit {
        _ = _dbClose()
    }
    
    // MARK: - fileprivate
    
    fileprivate func saveItem(key: String, value: Data, filename: String? = nil) -> Bool {
        if key.isEmpty || value.count <= 0 { return false }
        
        if let filename = filename, !filename.isEmpty {
            if !_fileWrite(data: value, withName: filename) { return false }
            if !_dbSave(key: key, value: value, filename: filename) {
                _ = _fileDelete(name: filename); return false
            }
            return true
        } else {
            return _dbSave(key: key, value: value, filename: filename)
        }
    }
    
    fileprivate func saveItem(_ item: Item) -> Bool {
        if let value = item.value {
            return saveItem(key: item.key, value: value, filename: item.filename)
        } else {
            return false
        }
    }
    
    fileprivate func removeItem(key: String) -> Bool {
        if key.isEmpty { return false }
        if let filename = _dbfilename(forKey: key) {
            _ = _fileDelete(name: filename)
        }
        return _dbDeleteItem(key: key)
    }
    
    fileprivate func removeItems(keys: [String]) -> Bool {
        if keys.isEmpty { return false }
        let filenames = _dbfilenames(forKeys: keys)
        for name in filenames {
            _ = _fileDelete(name: name)
        }
        return _dbDeleteItems(keys: keys)
    }
    
    fileprivate func removeAllItems() -> Bool {
        if !_dbClose() { return false }
        _reset()
        if !_dbOpen() { return false }
        if !_dbInitialize() { return false }
        return true
    }
    
    fileprivate func removeItemsLargerThan(size: Int) -> Bool {
        if size <= 0 { return removeAllItems() }
        let filenames = _dbfilenamesWhichSizeLargerThan(size: size)
        for name in filenames {
            _ = _fileDelete(name: name)
        }
        if _dbDeleteItemsWhichSizeLargerThan(size: size) {
            _dbCheckpoint()
            return true
        }
        return false
    }
    
    fileprivate func removeItemsEarlierThan(time: Int) -> Bool {
        if time <= 0 { return true }
        let filenames = _dbfilenamesWhichTimeEarlierThan(time: time)
        for name in filenames {
            _ = _fileDelete(name: name)
        }
        if _dbDeleteItemsWhichTimeEarlierThan(time: time) {
            _dbCheckpoint()
            return true
        }
        return false
    }
    
    fileprivate func removeItemsToFit(size: Int) -> Bool {
        if size <= 0 { return removeAllItems() }
        
        var total = _dbTotalItemsSize()
        if total < 0 { return false }
        if total <= size { return true }
        
        var items = [Item]()
        var suc = false
        repeat {
            items = _dbItemSizeOrderByTimeAsc(limitCount: 16)
            for item in items {
                if total > size {
                    if let name = item.filename {
                        _ = _fileDelete(name: name)
                    }
                    suc = _dbDeleteItem(key: item.key)
                    total -= item.size
                } else { break }
                if !suc { break }
            }
        } while total > size && !items.isEmpty && suc
        if suc { _dbCheckpoint() }
        return suc
    }
    
    fileprivate func removeItemsToFit(count: Int) -> Bool {
        if count <= 0 { return removeAllItems() }
        
        var total = _dbTotalItemsCount()
        if total < 0 { return false }
        if total <= count { return true }
        
        var items = [Item]()
        var suc = false
        repeat {
            items = _dbItemSizeOrderByTimeAsc(limitCount: 16)
            for item in items {
                if total > count {
                    if let name = item.filename {
                        _ = _fileDelete(name: name)
                    }
                    suc = _dbDeleteItem(key: item.key)
                    total -= 1
                } else { break }
                if !suc { break }
            }
        } while total > count && !items.isEmpty && suc
        if suc { _dbCheckpoint() }
        return suc
    }
    
    fileprivate func removeAllItems(progress: (_ removedCount: Int, _ totalCount: Int) -> (), finish: (_ success: Bool) -> ()) {
        let total = _dbTotalItemsCount()
        if total <= 0 {
            finish(total == 0)
        } else {
            var leftTotal = total
            var items = [Item]()
            var suc = false
            repeat {
                items = _dbItemSizeOrderByTimeAsc(limitCount: 32)
                for item in items {
                    if leftTotal > 0 {
                        if let name = item.filename {
                            _ = _fileDelete(name: name)
                        }
                        suc = _dbDeleteItem(key: item.key)
                        leftTotal -= 1
                    } else { break }
                    if !suc { break }
                }
                progress(total - leftTotal, total)
            } while leftTotal > 0 && !items.isEmpty && suc
            if suc { _dbCheckpoint() }
            finish(suc)
        }
    }
    
    fileprivate func item(forKey key: String) -> Item? {
        if key.isEmpty { return nil }
        guard let item = _dbItem(forKey: key, useInlineData: true) else { return nil }
        _ = _dbUpdateAccessTime(key: key)
        if let filename = item.filename, !filename.isEmpty {
            item.value = _fileRead(name: filename)
            if item.value == nil {
                _ = _dbDeleteItem(key: key)
                return nil
            }
        }
        return item
    }
    
    fileprivate func itemInfo(forKey key: String) -> Item? {
        if key.isEmpty { return nil }
        return _dbItem(forKey: key, useInlineData: false)
    }
    
    fileprivate func itemValue(forKey key: String) -> Data? {
        if key.isEmpty { return nil }
        var value: Data?
        if let name = _dbfilename(forKey: key) {
            value = _fileRead(name: name)
            if value == nil {
                _ = _dbDeleteItem(key: key)
            }
        } else {
            value = _dbValue(forKey: key)
        }
        if value != nil {
            _ = _dbUpdateAccessTime(key: key)
        }
        return value
    }
    
    fileprivate func items(forKeys keys: [String]) -> [Item] {
        if keys.isEmpty { return [] }
        var items = _dbItems(forKeys: keys, useInlineData: true)
        
        
        items = items.filter { (item) -> Bool in
            if let name = item.filename {
                item.value = _fileRead(name: name)
                if item.value == nil {
                    _ = _dbDeleteItem(key: item.key)
                }
            }
            return item.value != nil
        }
        
        if !items.isEmpty {
            _ = _dbUpdateAccessTime(keys: keys)
        }
        return items
    }
    
    fileprivate func itemInfos(forKeys keys: [String]) -> [Item] {
        if keys.isEmpty { return [] }
        return _dbItems(forKeys: keys, useInlineData: false)
    }
    
    fileprivate func itemValues(forKeys keys: [String]) -> [String: Data] {
        let items = self.items(forKeys: keys)
        var dict = [String: Data]()
        
        items.forEach { (item) in
            if let value = item.value {
                dict[item.key] = value
            }
        }
        return dict
    }
    
    fileprivate func itemExists(forKey key: String) -> Bool {
        if key.isEmpty { return false }
        return _dbItemCount(forKey: key) > 0
    }
    
    fileprivate func itemsCount() -> Int {
        return _dbTotalItemsCount()
    }
    
    fileprivate func itemsSize() -> Int {
        return _dbTotalItemsSize()
    }
    
    // MARK: - private
    
    private let _path: String
    
    private let Max_Error_Retry_Count = 8
    
    private let Min_Retry_Time_Interval: TimeInterval = 2.0
    
    private func _reset() {
        try? FileManager.default.removeItem(atPath: _dbPath)
        try? FileManager.default.removeItem(atPath: _dbPath + "-shm")
        try? FileManager.default.removeItem(atPath: _dbPath + "-wal")
        _ = _fileMoveAllToTrash()
        _fileEmptyTrashInBackground()
    }
    
    // MARK: - file
    
    private let _dataPath: String
    
    private let _trashPath: String
    
    private let _trashQueue = DispatchQueue(label: "_trashQueue", qos: .background) // background for Disk I/O Throttle
    
    private func _fileWrite(data: Data, withName name: String) -> Bool {
        let filePath = _dataPath.appending("/" + name)
        let url = URL(fileURLWithPath: filePath)
        do {
            try data.write(to: url)
        } catch {
            print(error)
            return false
        }
        return true
    }
    
    private func _fileRead(name: String) -> Data? {
        let filePath = _dataPath.appending("/" + name)
        let url = URL(fileURLWithPath: filePath)
        let data = try? Data(contentsOf: url)
        return data
    }
    
    private func _fileDelete(name: String) -> Bool {
        let filePath = _dataPath.appending("/" + name)
        do {
            try FileManager.default.removeItem(atPath: filePath)
        } catch {
            print(error)
            return false
        }
        return true
    }
    
    private func _fileMoveAllToTrash() -> Bool {
        let tmpPath = _trashPath.appending("/" + NSUUID().uuidString)
        do {
            try FileManager.default.moveItem(atPath: _dataPath, toPath: tmpPath)
            try FileManager.default.createDirectory(atPath: self._dataPath, withIntermediateDirectories: true)
        } catch {
            print(error)
            return false
        }
        return true
    }
    
    private func _fileEmptyTrashInBackground() {
        _trashQueue.async {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: self._trashPath) else { return }
            contents.forEach({ (path) in
                let fullPath = self._trashPath.appending("/" + path)
                try? FileManager.default.removeItem(atPath: fullPath)
            })
        }
    }
    
    
    // MARK: - DB
    
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    private var _db: sqlite3? // sqlite3 *
    
    private var _dbPath: String
    
    private var _dbStmtCache: [String: sqlite3_stmt] = [String: sqlite3_stmt]() // sql: sqlite_stmt *
    
    private var _dbOpenErrorCount: Int = 0
    
    private var _dbLastOpenErrorTime: TimeInterval = 0.0
    
    private func _dbOpen() -> Bool {
        
        let result = sqlite3_open(_dbPath, &_db) // sqlite3_open_v2(_dbPath, &_db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) //
        if result == SQLITE_OK {
            _dbOpenErrorCount = 0
            _dbLastOpenErrorTime = 0
            return true
        } else {
            _db = nil
            _dbOpenErrorCount += 1
            _dbLastOpenErrorTime = CACurrentMediaTime()
            return false
        }
    }
    
    private func _dbInitialize() -> Bool {
        let sql = "pragma journal_mode = wal; pragma synchronous = normal; create table if not exists manifest (key text, filename text, size integer, inline_data blob, modification_time integer, last_access_time integer, primary key(key)); create index if not exists last_access_time_idx on manifest(last_access_time);"
        return _dbExecute(sql: sql)
    }
    
    private func _dbClose() -> Bool  {
        guard let db = _db else { return true }
        var result: Int32
        var retry: Bool
        var isStmtFinalized = false
        _dbStmtCache.removeAll()
        
        repeat {
            retry = false
            result = sqlite3_close_v2(db)
            if result == SQLITE_BUSY || result == SQLITE_LOCKED {
                if !isStmtFinalized {
                    isStmtFinalized = true
                    var stmt = sqlite3_next_stmt(db, nil)
                    while stmt != nil {
                        sqlite3_finalize(stmt)
                        stmt = sqlite3_next_stmt(db, nil)
                        retry = true
                    }
                }
            }
        } while retry
        _db = nil
        return result == SQLITE_OK
    }
    
    private func _dbCheck() -> Bool {
        if _db == nil {
            if _dbOpenErrorCount < Max_Error_Retry_Count && CACurrentMediaTime() - _dbLastOpenErrorTime > Min_Retry_Time_Interval {
                return _dbOpen() && _dbInitialize()
            } else {
                return false
            }
        }
        return true
    }
    
    private func _dbCheckpoint() {  // 同步 wal sqlite
        if !_dbCheck() { return }
        sqlite3_wal_checkpoint(_db, nil)
    }
    
    private func _dbExecute(sql: String) -> Bool {
        if sql.isEmpty { return false }
        if !_dbCheck() { return false }
        
        return sqlite3_exec(_db, sql, nil, nil, nil) == SQLITE_OK
    }
    
    private func _dbPrepareStmt(sql: String) -> sqlite3_stmt? {
        if sql.isEmpty || !_dbCheck() { return nil }
        var stmt = _dbStmtCache[sql]
        if stmt == nil {
            let result = sqlite3_prepare_v2(_db, sql, -1, &stmt, nil)
            if result != SQLITE_OK { return nil }
            _dbStmtCache[sql] = stmt
        } else {
            sqlite3_reset(stmt)
        }
        return stmt
    }
    
    private func _dbJoined(keys: [String]) -> String {
        var string = String()
        for i in 0..<keys.count {
            string.append("?")
            if i + 1 != keys.count {
                string.append(",")
            }
        }
        return string
    }
    
    private func _dbBind(joinedKeys: [String], stmt: sqlite3_stmt, fromIndex index: Int) {
        for (i, key) in joinedKeys.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + i), key, -1, SQLITE_TRANSIENT)
        }
    }
    
    private func _dbSave(key: String, value: Data, filename: String?) -> Bool {
        
        let sql = "insert or replace into manifest (key, filename, size, inline_data, modification_time, last_access_time) values (?1, ?2, ?3, ?4, ?5, ?6);"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return false }
        let timeStamp = time(nil)
        sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, filename, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, Int32(value.count))
        
        if filename?.isEmpty ?? true {
            sqlite3_bind_blob(stmt, 4, [UInt8](value), Int32(value.count), SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_blob(stmt, 4, nil, 0, nil)
        }
        
        sqlite3_bind_int(stmt, 5, Int32(timeStamp))
        sqlite3_bind_int(stmt, 6, Int32(timeStamp))
        
        return sqlite3_step(stmt) == SQLITE_DONE
    }
    
    private func _dbUpdateAccessTime(key: String) -> Bool {
        let sql = "update manifest set last_access_time = ?1 where key = ?2;"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return false }
        sqlite3_bind_int(stmt, 1, Int32(time(nil)))
        sqlite3_bind_text(stmt, 2, key, -1, SQLITE_TRANSIENT)
        return sqlite3_step(stmt) == SQLITE_DONE
    }
    
    private func _dbUpdateAccessTime(keys: [String]) -> Bool {
        if !_dbCheck() { return false }
        let t = Int32(time(nil))
        let sql = "update manifest set last_access_time = \(t) where key in (\(_dbJoined(keys: keys)));"
        var stmt: sqlite3_stmt? = nil
        if sqlite3_prepare_v2(_db, sql, -1, &stmt, nil) != SQLITE_OK { return false }
        _dbBind(joinedKeys: keys, stmt: stmt!, fromIndex: 1)
        let result = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        return result == SQLITE_DONE
    }
    
    private func _dbDeleteItem(key: String) -> Bool {
        let sql = "delete from manifest where key = ?1;"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return false }
        sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        return sqlite3_step(stmt) == SQLITE_DONE
    }
    
    private func _dbDeleteItems(keys: [String]) -> Bool {
        if !_dbCheck() { return false }
        let sql = "delete from manifest where key in (\(_dbJoined(keys: keys)));"
        var stmt: sqlite3_stmt? = nil
        if sqlite3_prepare_v2(_db, sql, -1, &stmt, nil) != SQLITE_OK { return false }
        _dbBind(joinedKeys: keys, stmt: stmt!, fromIndex: 1)
        let result = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        return result == SQLITE_DONE
    }
    
    private func _dbDeleteItemsWhichSizeLargerThan(size: Int) -> Bool {
        let sql = "delete from manifest where size > ?1;"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return false }
        sqlite3_bind_int(stmt, 1, Int32(size))
        return sqlite3_step(stmt) == SQLITE_DONE
    }
    
    private func _dbDeleteItemsWhichTimeEarlierThan(time: Int) -> Bool {
        let sql = "delete from manifest where last_access_time < ?1;"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return false }
        sqlite3_bind_int(stmt, 1, Int32(time))
        return sqlite3_step(stmt) == SQLITE_DONE
    }
    
    private func _dbItem(stmt: sqlite3_stmt, useInlineData: Bool) -> Item? {
        guard let key = sqlite3_column_text(stmt, 0) else { return nil }
        let filename = sqlite3_column_text(stmt, 1)
        let size = sqlite3_column_int(stmt, 2)
        let inline_data = useInlineData ? sqlite3_column_blob(stmt, 3) : nil
        let inline_data_bytes = useInlineData ? sqlite3_column_bytes(stmt, 3) : 0
        let modification_time = sqlite3_column_int(stmt, 4)
        let last_access_time = sqlite3_column_int(stmt, 5)
        
        var data: Data? = nil
        if let inline_data = inline_data, inline_data_bytes > 0 {
            data = Data(bytes: inline_data, count: Int(inline_data_bytes))
        }
        let name = filename != nil ? String(cString: filename!) : nil
        return Item(key: String(cString: key), value: data, filename: name, size: Int(size), modTime: Int(modification_time), accessTime: Int(last_access_time))
    }
    
    private func _dbItem(forKey key: String, useInlineData: Bool) -> Item? {
        let sql = useInlineData ? "select key, filename, size, inline_data, modification_time, last_access_time from manifest where key = ?1;" : "select key, filename, size, modification_time, last_access_time from manifest where key = ?1;"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return nil }
        sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        let result = sqlite3_step(stmt)
        
        if result == SQLITE_ROW {
            return _dbItem(stmt: stmt, useInlineData: useInlineData)
        } else {
            return nil
        }
    }
    
    private func _dbItems(forKeys keys: [String], useInlineData: Bool) -> [Item] {
        if !_dbCheck() { return [] }
        let sql = useInlineData ? "select key, filename, size, inline_data, modification_time, last_access_time from manifest where key in (\(_dbJoined(keys: keys)))" : "select key, filename, size, modification_time, last_access_time from manifest where key in (\(_dbJoined(keys: keys)));"
        var stmt: sqlite3_stmt? = nil
        if sqlite3_prepare_v2(_db, sql, -1, &stmt, nil) != SQLITE_OK { return [] }
        //        guard let stm = stmt else { return [] }
        _dbBind(joinedKeys: keys, stmt: stmt!, fromIndex: 1)
        
        var items = [Item]()
        
        repeat {
            let result = sqlite3_step(stmt)
            if result == SQLITE_ROW, let item = _dbItem(stmt: stmt!, useInlineData: useInlineData) {
                items.append(item)
            } else if result == SQLITE_DONE {
                break
            } else {
                items = []; break
            }
        } while true
        sqlite3_finalize(stmt)
        return items
    }
    
    private func _dbValue(forKey key: String) -> Data? {
        let sql = "select inline_data from manifest where key = ?1;"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return nil }
        sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW,
            let inline_data = sqlite3_column_blob(stmt, 0) else { return nil }
        let inline_data_bytes = sqlite3_column_bytes(stmt, 0)
        if inline_data_bytes > 0 {
            return Data(bytes: inline_data, count: Int(inline_data_bytes))
        } else {
            return nil
        }
    }
    
    private func _dbfilename(forKey key: String) -> String? {
        let sql = "select filename from manifest where key = ?1;"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return nil }
        sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW {
            guard let n = sqlite3_column_text(stmt, 0), n.pointee != 0 else { return nil }
            return String(cString: n)
        } else {
            return nil
        }
    }
    
    private func _dbfilenames(forKeys keys: [String]) -> [String] {
        if !_dbCheck() { return [] }
        let sql = "select filename from manifest where key in (\(_dbJoined(keys: keys)));"
        var stmt: sqlite3_stmt? = nil
        if sqlite3_prepare_v2(_db, sql, -1, &stmt, nil) != SQLITE_OK { return [] }
        _dbBind(joinedKeys: keys, stmt: stmt!, fromIndex: 1)
        
        var filenames = [String]()
        repeat {
            let result = sqlite3_step(stmt)
            if result == SQLITE_ROW {
                if let n = sqlite3_column_text(stmt, 0), n.pointee != 0 {
                    filenames.append(String(cString: n))
                }
            } else if result == SQLITE_DONE {
                break
            } else {
                filenames = []; break
            }
        } while true
        sqlite3_finalize(stmt)
        return filenames
    }
    
    private func _dbfilenamesWhichSizeLargerThan(size: Int) -> [String] {
        let sql = "select filename from manifest where size > ?1 and filename is not null;"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return [] }
        sqlite3_bind_int(stmt, 1, Int32(size))
        var filenames = [String]()
        repeat {
            let result = sqlite3_step(stmt)
            if result == SQLITE_ROW {
                if let n = sqlite3_column_text(stmt, 0), n.pointee != 0 {
                    filenames.append(String(cString: n))
                }
            } else if result == SQLITE_DONE {
                break
            } else {
                filenames = []; break
            }
        } while true
        return filenames
    }
    
    private func _dbfilenamesWhichTimeEarlierThan(time: Int) -> [String] {
        let sql = "select filename from manifest where last_access_time < ?1 and filename is not null;"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return [] }
        sqlite3_bind_int(stmt, 1, Int32(time))
        var filenames = [String]()
        repeat {
            let result = sqlite3_step(stmt)
            if result == SQLITE_ROW {
                if let n = sqlite3_column_text(stmt, 0), n.pointee != 0 {
                    filenames.append(String(cString: n))
                }
            } else if result == SQLITE_DONE {
                break
            } else {
                filenames = []; break
            }
        } while true
        return filenames
    }
    
    private func _dbItemSizeOrderByTimeAsc(limitCount: Int) -> [Item] {
        let sql = "select key, filename, size from manifest order by last_access_time asc limit ?1;"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return [] }
        sqlite3_bind_int(stmt, 1, Int32(limitCount))
        var items = [Item]()
        repeat {
            let result = sqlite3_step(stmt)
            if result == SQLITE_ROW {
                if let key = sqlite3_column_text(stmt, 0) {
                    let filename = sqlite3_column_text(stmt, 1)
                    let size = sqlite3_column_int(stmt, 2)
                    let name = filename != nil ? String(cString: filename!) : nil
                    items.append(Item(key: String(cString: key), value: nil, filename: name, size: Int(size), modTime: 0, accessTime: 0))
                }
                
            } else if result == SQLITE_DONE {
                break
            } else {
                items = []; break
            }
        } while true
        return items
    }
    
    private func _dbItemCount(forKey key: String) -> Int {
        let sql = "select count(key) from manifest where key = ?1;"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return -1 }
        sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_ROW { return -1 }
        return Int(sqlite3_column_int(stmt, 0))
    }
    
    private func _dbTotalItemsCount() -> Int {
        let sql = "select count(*) from manifest;"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return -1 }
        if sqlite3_step(stmt) != SQLITE_ROW { return -1 }
        return Int(sqlite3_column_int(stmt, 0))
    }
    
    private func _dbTotalItemsSize() -> Int {
        let sql = "select sum(size) from manifest;"
        guard let stmt = _dbPrepareStmt(sql: sql) else { return -1 }
        if sqlite3_step(stmt) != SQLITE_ROW { return -1 }
        return Int(sqlite3_column_int(stmt, 0))
    }
    
}

















