//
//  Rope+Collection.swift
//  
//
//  Created by David Albert on 6/12/23.
//

import Foundation

extension Rope {
    struct PathElement {
        // An index is valid only if it's root present and it's mutation
        // count is equal to the root's mutation count. If both of those
        // are true, we're guaranteed that the path is valid, so we can
        // unowned instead of weak references for the nodes.
        unowned var node: Node
        var slot: Int // child index

        var child: Node {
            node.children[slot]
        }
    }

    struct Index {
        var nodeIndex: NodeIndex

        init(startOf rope: Rope) {
            self.nodeIndex = NodeIndex(startOf: rope.root)
        }

        init(endOf rope: Rope) {
            self.nodeIndex = NodeIndex(endOf: rope.root)
        }

        init(offsetBy offset: Int, in rope: Rope) {
            self.nodeIndex = NodeIndex(offsetBy: offset, in: rope.root)
        }

        mutating func formSuccessor() {
            self.nodeIndex.formSuccessor()
        }

        mutating func formPredecessor() {
            self.nodeIndex.formPredecessor()
        }

        var value: Character? {
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

extension Rope.Index: Comparable {
    static func < (left: Rope.Index, right: Rope.Index) -> Bool {
        left.nodeIndex < right.nodeIndex        
    }

    static func == (left: Rope.Index, right: Rope.Index) -> Bool {
        left.nodeIndex == right.nodeIndex
    }
}

extension Rope: BidirectionalCollection {
    struct Iterator: IteratorProtocol {
        let rope: Rope // retain rope to make sure it doesn't get dealocated during iteration
        var index: Index

        init(rope: Rope) {
            self.rope = rope
            self.index = rope.startIndex
        }

        mutating func next() -> Character? {
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

    subscript(index: Index) -> Character {
        index.validate(for: root)
        return index.value!
    }

    subscript(offset: Int) -> Character {
        // Index(offsetBy:in:) will let you create an index that's == endIndex,
        // but we don't want to allow that for subscripting.
        precondition(offset < count, "Index out of bounds")
        return Index(offsetBy: offset, in: self).value!
    }

    subscript(bounds: Range<Index>) -> Rope {
        bounds.lowerBound.validate(for: root)
        bounds.upperBound.validate(for: root)

        var b = Builder()
        b.push(root, slicedBy: Range(bounds))
        return Rope(b.build())
    }

    subscript(offsetRange: Range<Int>) -> Rope {
        precondition(offsetRange.lowerBound >= 0, "Index out of bounds")
        precondition(offsetRange.upperBound <= count, "Index out of bounds")

        var b = Builder()
        b.push(root, slicedBy: offsetRange)
        return Rope(b.build())
    }
}

extension Rope: RangeReplaceableCollection {
    mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C : Collection, Character == C.Element {
        replaceSubrange(subrange, with: String(newElements))
    }

    mutating func replaceSubrange(_ subrange: Range<Index>, with string: String) {
        subrange.lowerBound.validate(for: root)
        subrange.upperBound.validate(for: root)

        var b = Builder()
        b.push(root, slicedBy: Range(startIndex..<subrange.lowerBound))
        b.push(string: string)
        b.push(root, slicedBy: Range(subrange.upperBound..<endIndex))
        self.root = b.build()
    }

    // override the default behavior
    mutating func reserveCapacity(_ n: Int) {
        // no-op
    }
}
