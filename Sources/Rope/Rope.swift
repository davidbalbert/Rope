//
//  File.swift
//  
//
//  Created by David Albert on 6/2/23.
//

import Foundation

// a rope made out of a B-tree
// internal nodes are order 8: 4...8 children
// leaf nodes are order 1024: 511..<1024 elements (characters), unless it's root, then 0..<1024

let minChild = 4
let maxChild = 8

let minLeaf = 511
let maxLeaf = 1023

struct Rope {
    var root: Node

    static func + (_ left: Rope, _ right: Rope) -> Rope {
        var b = Builder()
        b.push(left.root)
        b.push(right.root)
        return Rope(b.build())
    }

    init(_ root: Node) {
        self.root = root
    }

    public init() {
        self.init(Node())
    }

    public init(_ string: String) {
        var b = Builder()
        b.push(string: string)
        self.init(b.build())
    }

    public init<S>(_ string: S) where S: Collection, S.Element == Character {
        var b = Builder()
        b.push(string: String(string))
        self.init(b.build())
    }

    var count: Int {
        return root.count
    }

    mutating func append(_ string: String) {
        append(contentsOf: string)
    }
}
