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
}

extension BTree where Summary: BTreeDefaultMetric {
    // TODO: right now, index(before:using:) and index(after:using:) can return invalid
    // indices. Perhaps we want them to return nil indices instead.
    func index<M>(before i: Index, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.validate(for: root)

        var i = i
        i.prev(using: metric)
        return i
    }

    func index<M>(after i: Index, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.validate(for: root)

        var i = i
        i.next(using: metric)
        return i
    }

    // TODO: index(_:offsetBy:using:) and index(_:offsetBy:limitedBy:using:) both panic if
    // m+distance > root.measure(using: metric). There are certain situations where we're probably
    // going to want to return the end of the rope if we're asking for root.measure(using: metric) + 1.
    //
    // Specifically, if we're using the .newlines metric, the number of lines we have is one more than
    // the number of newline characters. For this reason, Xi allows you to call offset_of_line with
    // root.measure(using: .newlines) + 1. It's possible we can handle this in the lines view instead
    // of in this method.
    //
    // If we want to handle it here, we could make this function return Index? as well.
    func index<M>(_ i: Index, offsetBy distance: Int, using metric: M) -> Index where M: BTreeMetric<Summary> {
        i.validate(for: root)

        var i = i
        let m = root.count(metric, upThrough: i.position)
        precondition(m+distance >= 0 && m+distance <= root.measure(using: metric), "Index out of bounds")
        let pos = root.offset(of: m + distance, measuredIn: metric)
        i.set(pos)
        // TODO: this could be a mutating i.setState(for: offset, using: m)
        i.state = root.state(for: m + distance, measuredIn: metric, at: i)

        return i
    }

    func index<M>(_ i: Index, offsetBy distance: Int, limitedBy limit: Index, using metric: M) -> Index? where M: BTreeMetric<Summary> {
        i.validate(for: root)
        limit.validate(for: root)

        let l = limit.position - i.position
        if distance > 0 ? l >= 0 && l < distance : l <= 0 && distance < l {
            return nil
        }

        // This is the body of index(_:offsetBy:in:) skipping the validation
        var i = i
        let m = root.count(metric, upThrough: i.position)
        precondition(m+distance >= 0 && m+distance <= root.measure(using: metric), "Index out of bounds")
        let pos = root.offset(of: m + distance, measuredIn: metric)
        i.set(pos)
        // TODO: this could be a mutating i.setState(for: offset, using: m)
        i.state = root.state(for: m + distance, measuredIn: metric, at: i)

        return i
    }

    func index<M>(roundingDown i: Index, using metric: M) -> Index where M: BTreeMetric<Summary> {
        if i.isBoundary(in: metric) {
            return i
        }

        return index(before: i, using: metric)
    }

    func index(roundingDownToNearestLeaf i: Index) -> Index {
        i.validate(for: root)

        var i = i
        _ = i.floorLeaf()! // a valid index will always have a leaf
        return i
    }

    func index<M>(at offset: Int, using metric: M) -> Index where M: BTreeMetric<Summary> {
        let count = root.offset(of: offset, measuredIn: metric)
        var i = Index(offsetBy: count, in: root)
        // TODO: this could be a mutating i.setState(for: offset, using: m)
        i.state = root.state(for: offset, measuredIn: metric, at: i)
        return i
    }
}
