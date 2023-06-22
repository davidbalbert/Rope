//
//  Tree+Collection.swift
//
//
//  Created by David Albert on 6/12/23.
//

import Foundation

extension Tree: BidirectionalCollection {
    struct Iterator: IteratorProtocol {
        let root: Node // retain the root to make sure it doesn't get dealocated during iteration
        var index: Index

        init(root: Node) {
            self.root = root
            self.index = Index(startOf: root)
        }

        mutating func next() -> Leaf.Element? {
            guard let c = index.value else { return nil }
            index.formSuccessor()
            return c
        }
    }

    func makeIterator() -> Iterator {
        Iterator(root: root)
    }

    var startIndex: Index {
        Index(startOf: root)
    }

    var endIndex: Index {
        Index(endOf: root)
    }

    // TODO: we should also overwrite the default implementation of
    // the index(_:offsetBy:) and formIndex(_:offsetBy:) family of
    // methods. In most cases, it'll be faster to traverse the tree
    // from the top rather than iterating by position. A decent
    // place to start might be iterate if we're within the same
    // leaf, and otherwise just use the NodeIndex(offsetBy:in:)
    // initializer.
    //
    // Honestly, we should probably audit the entirety of
    // Collection and BidirectionalCollection. I bet we'll want
    // to override most things.

    func index(before i: Index) -> Index {
        i.validate(for: root)
        var i = i
        i.formPredecessor()
        return i
    }

    func index(after i: Index) -> Index {
        i.validate(for: root)
        var i = i
        i.formSuccessor()
        return i
    }

    func formIndex(before i: inout Index) {
        i.validate(for: root)
        i.formPredecessor()
    }

    func formIndex(after i: inout Index) {
        i.validate(for: root)
        i.formSuccessor()
    }

    subscript(index: Index) -> Leaf.Element {
        index.validate(for: root)
        return index.value!
    }

    subscript(offset: Int) -> Leaf.Element {
        // Index(offsetBy:in:) will let you create an index that's == endIndex,
        // but we don't want to allow that for subscripting.
        precondition(offset < count, "Index out of bounds")
        return Index(offsetBy: offset, in: root).value!
    }

    // Does not actually mutate
    subscript(bounds: Range<Index>) -> Tree {
        bounds.lowerBound.validate(for: root)
        bounds.upperBound.validate(for: root)

        var r = root

        var b = Builder()
        b.push(&r, slicedBy: Range(bounds))
        return Tree(b.build())
    }

    subscript(offsetRange: Range<Int>) -> Tree {
        precondition(offsetRange.lowerBound >= 0, "Index out of bounds")
        precondition(offsetRange.upperBound <= count, "Index out of bounds")

        var r = root

        var b = Builder()
        b.push(&r, slicedBy: offsetRange)
        return Tree(b.build())
    }
}
