//
//  Tree.swift
//  
//
//  Created by David Albert on 6/2/23.
//

import Foundation

struct Tree<Summary> where Summary: SummaryProtocol {
    static var minChild: Int { 4 }
    static var maxChild: Int { 8 }

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
