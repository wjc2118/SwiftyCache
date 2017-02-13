//
//  ViewController.swift
//  Demo
//
//  Created by wjc2118 on 2017/2/13.
//  Copyright © 2017年 wjc2118. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    let cache: SwiftyCache! = SwiftyCache(name: "cache")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        
        print(cache.object(forKey: "string") as Any)
        cache.setObject("xyz", forKey: "string")
        print(cache.object(forKey: "string") as Any)
        
        print(cache.object(forKey: "array") as Any)
        cache.setObject([1, 2, 3], forKey: "array")
        print(cache.object(forKey: "array") as Any)
        
        print(cache.object(forKey: "struct", CachedType: MyStruct.self) as Any)
        cache.set(object: MyStruct(num: 5, str: "abc"), forKey: "struct")
        print(cache.object(forKey: "struct", CachedType: MyStruct.self) as Any)
    }


}

struct MyStruct {
    let num: Int
    let str: String
}

extension MyStruct: Datable {
    var keyValues: [String : Any] {
        return ["n": num, "s": str]
    }
    
    init?(keyValues: [String : Any]?) {
        guard let dict = keyValues, let n = dict["n"] as? Int, let s = dict["s"] as? String else { return nil }
        self.init(num: n, str: s)
    }
}

