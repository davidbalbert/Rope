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
        b.push(string: string)
        self.init(b.build())
    }

    var count: Int {
        return root.count
    }

    mutating func append(_ c: Character) {
        insert(c, at: endIndex)
    }

    mutating func insert(_ c: Character, at i: Index) {
        i.validate(for: root)
        if !isKnownUniquelyReferenced(&root) {
            root = root.clone()
        }

        if let node = root.insert(c, at: i.nodeIndex.position) {
            root = node
        }
    }

    // mutating func insert<S>(contentsOf newElements: S, at i: Index) where S: Collection, S.Element == Character {
    //     i.validate(for: root)
    //     ensureUniqueRoot()

    //     if let node = root.insert(contentsOf: newElements, at: i.position) {
    //         root = node
    //     }
    // }
}
