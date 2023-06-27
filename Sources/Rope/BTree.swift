//
//  BTree.swift
//
//
//  Created by David Albert on 6/2/23.
//

import Foundation

struct BTree<Summary> where Summary: BTreeSummary {
    static var minChild: Int { 4 }
    static var maxChild: Int { 8 }

    typealias Leaf = Summary.Leaf

    var root: Node

    static func + (_ left: BTree, _ right: BTree) -> BTree {
        var l = left.root
        var r = right.root

        var b = Builder()
        b.push(&l)
        b.push(&r)
        return BTree(b.build())
    }

    init(_ root: Node) {
        self.root = root
    }

    public init() {
        self.init(Node())
    }

    var count: Int {
        root.count
    }

    var isEmpty: Bool {
        root.isEmpty
    }
}
