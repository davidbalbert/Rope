//
//  Tree+Collection.swift
//
//
//  Created by David Albert on 6/12/23.
//

import Foundation

extension Tree {
    struct Index {
        var nodeIndex: NodeIndex

        init(startOf rope: Tree) {
            self.nodeIndex = NodeIndex(startOf: rope.root)
        }

        init(endOf rope: Tree) {
            self.nodeIndex = NodeIndex(endOf: rope.root)
        }

        init(offsetBy offset: Int, in rope: Tree) {
            self.nodeIndex = NodeIndex(offsetBy: offset, in: rope.root)
        }

        mutating func formSuccessor() {
            self.nodeIndex.formSuccessor()
        }

        mutating func formPredecessor() {
            self.nodeIndex.formPredecessor()
        }

        var value: Leaf.Element? {
            nodeIndex.value
        }

        func validate(for root: Node) {
            nodeIndex.validate(for: root)
        }

        func validate(_ other: NodeIndex) {
            nodeIndex.validate(other)
        }
    }
}

extension Tree.Index: Comparable {
    static func < (left: Tree.Index, right: Tree.Index) -> Bool {
        left.nodeIndex < right.nodeIndex        
    }

    static func == (left: Tree.Index, right: Tree.Index) -> Bool {
        left.nodeIndex == right.nodeIndex
    }
}

extension Tree: BidirectionalCollection {
    struct Iterator: IteratorProtocol {
        let rope: Tree // retain rope to make sure it doesn't get dealocated during iteration
        var index: Index

        init(rope: Tree) {
            self.rope = rope
            self.index = rope.startIndex
        }

        mutating func next() -> Leaf.Element? {
            guard let c = index.value else { return nil }
            index.formSuccessor()
            return c
        }
    }

    func makeIterator() -> Iterator {
        Iterator(rope: self)
    }

    var startIndex: Index {
        Index(startOf: self)
    }

    var endIndex: Index {
        Index(endOf: self)
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
        return Index(offsetBy: offset, in: self).value!
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
