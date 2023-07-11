//
//  Views.swift
//  Rope
//
//  Created by David Albert on 6/30/23.
//

import Foundation

extension BTree {
    var leaves: LeavesView {
        LeavesView(base: self)
    }

    struct LeavesView {
        var base: BTree
    }
}

extension BTree.LeavesView: Sequence {
    struct Iterator: IteratorProtocol {
        var index: BTree.Index

        mutating func next() -> Summary.Leaf? {
            guard let (leaf, _) = index.read() else {
                return nil
            }

            index.nextLeaf()
            return leaf
        }
    }

    func makeIterator() -> Iterator {
        Iterator(index: BTree.Index(startOf: base.root))
    }
}

// N.b. These will be accessable as BTree.*View, BTree<RopeSummary>.*View,
// and Rope.*View, but not BTree<SomeOtherSummary>.*View.
extension Rope {
    var utf8: UTF8View {
        UTF8View(base: self)
    }

    struct UTF8View {
        var base: Rope
    }
}

// TODO: make this extension implement BidirectionalCollection
extension Rope.UTF8View {
    var count: Int {
        base.root.measure(using: .utf8)
    }
}

extension Rope {
    var utf16: UTF16View {
        UTF16View(base: self)
    }

    struct UTF16View {
        var base: Rope
    }
}

extension Rope.UTF16View: BidirectionalCollection {
    struct Iterator: IteratorProtocol {
        var index: Rope.Index

        mutating func next() -> UTF16.CodeUnit? {
            let u = index.readUTF16()
            index.next(using: .utf16)
            return u
        }
    }

    func makeIterator() -> Iterator {
        Iterator(index: Index(startOf: base.root))
    }

    var startIndex: Rope.Index {
        base.startIndex
    }

    var endIndex: Rope.Index {
        base.endIndex
    }

    subscript(position: Rope.Index) -> UTF16.CodeUnit {
        position.validate(for: base.root)
        return position.readUTF16()!
    }

    func index(before i: Rope.Index) -> Rope.Index {
        base.index(before: i, using: .utf16)
    }

    func index(after i: Rope.Index) -> Rope.Index {
        base.index(after: i, using: .utf16)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int) -> Rope.Index {
        base.index(i, offsetBy: distance, using: .utf16)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int, limitedBy limit: Rope.Index) -> Rope.Index? {
        base.index(i, offsetBy: distance, limitedBy: limit, using: .utf16)
    }

    var count: Int {
        base.root.measure(using: .utf16)
    }
}

extension Rope.UTF16View {
    subscript(offset: Int) -> UTF16.CodeUnit {
        self[base.index(at: offset, using: .utf16)]
    }
}

extension Rope {
    var unicodeScalars: UnicodeScalarView {
        UnicodeScalarView(base: self)
    }

    struct UnicodeScalarView {
        var base: Rope
    }
}

extension Rope.UnicodeScalarView: BidirectionalCollection {
    struct Iterator: IteratorProtocol {
        var index: Rope.Index

        mutating func next() -> Unicode.Scalar? {
            let scalar = index.readScalar()
            index.next(using: .unicodeScalars)
            return scalar
        }
    }

    func makeIterator() -> Iterator {
        Iterator(index: Index(startOf: base.root))
    }

    var startIndex: Rope.Index {
        base.startIndex
    }

    var endIndex: Rope.Index {
        base.endIndex
    }

    subscript(position: Rope.Index) -> Unicode.Scalar {
        position.validate(for: base.root)
        return position.readScalar()!
    }

    func index(before i: Rope.Index) -> Rope.Index {
        base.index(before: i, using: .unicodeScalars)
    }

    func index(after i: Rope.Index) -> Rope.Index {
        base.index(after: i, using: .unicodeScalars)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int) -> Rope.Index {
        base.index(i, offsetBy: distance, using: .unicodeScalars)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int, limitedBy limit: Rope.Index) -> Rope.Index? {
        base.index(i, offsetBy: distance, limitedBy: limit, using: .unicodeScalars)
    }

    var count: Int {
        base.root.measure(using: .unicodeScalars)
    }
}

extension Rope.UnicodeScalarView {
    subscript(offset: Int) -> UnicodeScalar {
        self[base.index(at: offset, using: .unicodeScalars)]
    }
}

extension Rope {
    var lines: LinesView {
        LinesView(base: self)
    }

    struct LinesView {
        var base: Rope
    }
}

// TODO: make this extension implement BidirectionalCollection
extension Rope.LinesView {
    var count: Int {
        base.root.measure(using: .newlines) + 1
    }
}
