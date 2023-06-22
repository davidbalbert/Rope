//
//  Tree.swift
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

struct Tree<Summary> where Summary: SummaryProtocol {
    typealias Leaf = Summary.Leaf
    typealias Element = Leaf.Element

    var root: Node

    static func + (_ left: Tree, _ right: Tree) -> Tree {
        var l = left.root
        var r = right.root

        var b = Builder()
        b.push(&l)
        b.push(&r)
        return Tree(b.build())
    }

    init(_ root: Node) {
        self.root = root
    }

    public init() {
        self.init(Node())
    }

    var count: Int {
        return root.count
    }
}
