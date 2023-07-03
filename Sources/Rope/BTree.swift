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

    init(_ tree: BTree, slicedBy range: Range<Int>) {
        assert(range.lowerBound >= 0 && range.lowerBound < tree.root.count)
        assert(range.upperBound >= 0 && range.upperBound < tree.root.count)

        var r = tree.root

        var b = Builder()
        b.push(&r, slicedBy: range)
        self.init(b.build())
    }

    var isEmpty: Bool {
        root.isEmpty
    }
}

extension BTree where Summary: BTreeDefaultMetric {
    func index(before i: Index, using metric: some BTreeMetric<Summary>) -> Index {
        i.validate(for: root)

        var i = i
        i.prev(using: metric)
        return i
    }

    func index(after i: Index, using metric: some BTreeMetric<Summary>) -> Index {
        i.validate(for: root)

        var i = i
        i.next(using: metric)
        return i
    }

    func index(_ i: Index, offsetBy distance: Int, using metric: some BTreeMetric<Summary>) -> Index {
        i.validate(for: root)

        var i = i
        let m = root.count(metric, upThrough: i.position)
        let pos = root.offset(of: m + distance, measuredIn: metric)
        i.set(pos)

        return i
    }

    func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index, using metric: some BTreeMetric<Summary>) -> Index? {
        i.validate(for: root)
        limit.validate(for: root)

        let l = limit.position - i.position
        if distance > 0 ? l >= 0 && l < distance : l <= 0 && distance < l {
            return nil
        }

        // This is the body of index(_:offsetBy:in:) skipping the validation
        var i = i
        let m = root.count(metric, upThrough: i.position)
        let pos = root.offset(of: m + distance, measuredIn: metric)
        i.set(pos)

        return i
    }

    func index(roundingDown i: Index, using metric: some BTreeMetric<Summary>) -> Index {
        if i.isBoundary(in: metric) {
            return i
        }

        return index(before: i, using: metric)
    }
}
