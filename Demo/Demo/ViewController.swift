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
        
        print(cache.value(forKey: "string") as Any)
        cache.setValue("xyz", forKey: "string")
        print(cache.value(forKey: "string") as Any)
        
        print(cache.value(forKey: "array") as Any)
        cache.setValue([1, 2, 3, 4], forKey: "array")
        print(cache.value(forKey: "array") as Any)
        
        print(cache.value(forKey: "struct", CachedType: MyStruct.self) as Any)
        cache.set(value: MyStruct(num: 5, str: "abc"), forKey: "struct")
        print(cache.value(forKey: "struct", CachedType: MyStruct.self) as Any)
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

