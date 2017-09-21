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
        
        print(cache.value(for: "string") as Any)
        cache.setValue("xyz", for: "string")
        print(cache.value(for: "string") as Any)
        
        print(cache.value(for: "array") as Any)
        cache.setValue([1, 2, 3, 4], for: "array")
        print(cache.value(for: "array") as Any)
        
        print(cache.decode(for: "test", type: Test.self) as Any)
        cache.encode(Test(num: 4, str: "aaa"), for: "test")
        print(cache.decode(for: "test", type: Test.self) as Any)
        
        var d = [Int: Test]()
        for i in 0..<5 {
            d[i] = Test(num: i, str: "abc")
        }
        print(cache.decode(for: "dict", type: [Int: Test].self) as Any)
        cache.encode(d, for: "dict")
        print(cache.decode(for: "dict", type: [Int: Test].self) as Any)
        
    }
    

}

struct Test: Codable {
    let num: Int
    let str: String
}



