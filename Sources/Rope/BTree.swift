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
        assert(range.lowerBound >= 0 && range.lowerBound <= tree.root.count)
        assert(range.upperBound >= 0 && range.upperBound <= tree.root.count)

        var r = tree.root

        var b = Builder()
        b.push(&r, slicedBy: range)
        self.init(b.build())
    }

    var isEmpty: Bool {
        root.isEmpty
    }

    var startIndex: Index {
        Index(startOf: root)
    }

    var endIndex: Index {
        Index(endOf: root)
    }
}

// These methods must be called with valid indices.
extension BTree where Summary: BTreeDefaultMetric {
    func index<M>(before i: Index, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.assertValid(for: root)

        var i = i
        let offset = i.prev(using: metric)
        if offset == nil {
            fatalError("Index out of bounds")
        }
        return i
    }

    func index<M>(after i: Index, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.assertValid(for: root)

        var i = i
        let offset = i.next(using: metric)
        if offset == nil {
            fatalError("Index out of bounds")
        }
        return i
    }

    func index<M>(_ i: Index, offsetBy distance: Int, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.assertValid(for: root)

        var i = i
        let m = root.count(metric, upThrough: i.position)
        precondition(m+distance >= 0 && m+distance <= root.measure(using: metric), "Index out of bounds")
        let pos = root.countBaseUnits(of: m + distance, measuredIn: metric)
        i.set(pos)

        return i
    }

    func index<M>(_ i: Index, offsetBy distance: Int, limitedBy limit: Index, using metric: M) -> Index? where M: BTreeMetric<Summary> {
        i.assertValid(for: root)
        limit.assertValid(for: root)

        let l = limit.position - i.position
        if distance > 0 ? l >= 0 && l < distance : l <= 0 && distance < l {
            return nil
        }

        return index(i, offsetBy: distance, using: metric)
    }

    func index<M>(roundingDown i: Index, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.assertValid(for: root)
        
        if i.isBoundary(in: metric) {
            return i
        }

        return index(before: i, using: metric)
    }

    func index<M>(at offset: Int, using metric: M) -> Index where M: BTreeMetric<Summary> {
        let count = root.countBaseUnits(of: offset, measuredIn: metric)
        return Index(offsetBy: count, in: root)
    }
}
