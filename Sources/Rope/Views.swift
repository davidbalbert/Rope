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

extension BTree.LeavesView: BidirectionalCollection {
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
        Iterator(index: base.startIndex)
    }

    var startIndex: BTree.Index {
        base.startIndex
    }

    var endIndex: BTree.Index {
        base.endIndex
    }

    subscript(position: BTree.Index) -> Summary.Leaf {
        position.validate(for: base.root)
        let (leaf, _) = position.read()!
        return leaf
    }

    func index(before i: BTree.Index) -> BTree.Index {
        var i = i
        _ = i.prevLeaf()!
        return i
    }

    func index(after i: BTree.Index) -> BTree.Index {
        var i = i
        _ = i.nextLeaf()!
        return i
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

        func index(at: Int) -> Index {
            base.index(at: at, using: .utf8)
        }

        func index(roundingDown i: Index) -> Index {
            i
        }
    }
}

extension Rope.UTF8View: BidirectionalCollection {
    struct Iterator: IteratorProtocol {
        var index: Rope.Index

        mutating func next() -> UTF8.CodeUnit? {
            let b = index.readUTF8()
            index.next(using: .utf8)
            return b
        }
    }

    func makeIterator() -> Iterator {
        Iterator(index: base.startIndex)
    }

    var startIndex: Rope.Index {
        base.startIndex
    }

    var endIndex: Rope.Index {
        base.endIndex
    }

    subscript(position: Rope.Index) -> UTF8.CodeUnit {
        position.validate(for: base.root)
        return position.readUTF8()!
    }

    func index(before i: Rope.Index) -> Rope.Index {
        base.index(before: i, using: .utf8)
    }

    func index(after i: Rope.Index) -> Rope.Index {
        base.index(after: i, using: .utf8)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int) -> Rope.Index {
        base.index(i, offsetBy: distance, using: .utf8)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int, limitedBy limit: Rope.Index) -> Rope.Index? {
        base.index(i, offsetBy: distance, limitedBy: limit, using: .utf8)
    }

    var count: Int {
        base.root.measure(using: .utf8)
    }
}

extension Rope.UTF8View {
    subscript(offset: Int) -> UTF8.CodeUnit {
        self[base.index(at: offset, using: .utf8)]
    }
}

extension Rope {
    var unicodeScalars: UnicodeScalarView {
        UnicodeScalarView(base: self)
    }

    struct UnicodeScalarView {
        var base: Rope

        func index(at: Int) -> Index {
            base.index(at: at, using: .unicodeScalars)
        }

        func index(roundingDown i: Index) -> Index {
            base.index(roundingDown: i, using: .unicodeScalars)
        }
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
        Iterator(index: base.startIndex)
    }

    var startIndex: Rope.Index {
        base.startIndex
    }

    var endIndex: Rope.Index {
        base.endIndex
    }

    subscript(position: Rope.Index) -> Unicode.Scalar {
        position.validate(for: base.root)
        return index(roundingDown: position).readScalar()!
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

        func index(at: Int) -> Index {
            base.index(at: at, using: .newlines)
        }

        func index(roundingDown i: Index) -> Index {
            base.index(roundingDown: i, using: .newlines)
        }
    }
}

extension Rope.LinesView: BidirectionalCollection {
    struct Iterator: IteratorProtocol {
        var index: Rope.Index

        mutating func next() -> String? {
            let scalar = index.readLine()
            index.next(using: .newlines)
            return scalar
        }
    }

    func makeIterator() -> Iterator {
        Iterator(index: base.startIndex)
    }

    var startIndex: Rope.Index {
        base.startIndex
    }

    var endIndex: Rope.Index {
        base.endIndex
    }

    subscript(position: Rope.Index) -> String {
        position.validate(for: base.root)
        return index(roundingDown: position).readLine()!
    }

    func index(before i: Rope.Index) -> Rope.Index {
        base.index(before: i, using: .newlines)
    }

    func index(after i: Rope.Index) -> Rope.Index {
        base.index(after: i, using: .newlines)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int) -> Rope.Index {
        base.index(i, offsetBy: distance, using: .newlines)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int, limitedBy limit: Rope.Index) -> Rope.Index? {
        base.index(i, offsetBy: distance, limitedBy: limit, using: .newlines)
    }

    var count: Int {
        base.root.measure(using: .newlines) + 1
    }
}

extension Rope.LinesView {
    subscript(offset: Int) -> String {
        self[base.index(at: offset, using: .newlines)]
    }
}
