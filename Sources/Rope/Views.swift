//
//  Views.swift
//  Rope
//
//  Created by David Albert on 6/30/23.
//

import Foundation

// N.b. These will be accessable as BTree.*View, BTree<RopeSummary>.*View,
// and Rope.*View, but not BTree<SomeOtherSummary>.*View.
extension Rope {
    var utf8: UTF8View {
        UTF8View(base: self)
    }

    struct UTF8View {
        var base: Rope

        func index(at: Int) -> Index {
            return base.index(at: at, using: .utf8)
        }

        func index(roundingDown i: Index) -> Index {
            i.validate(for: base.root)
            return i
        }

        subscript(offset: Int) -> UTF8.CodeUnit {
            self[base.index(at: offset, using: .utf8)]
        }
    }
}

extension Rope.UTF8View: BidirectionalCollection {
    struct Iterator: IteratorProtocol {
        var index: Rope.Index

        mutating func next() -> UTF8.CodeUnit? {
            guard let b = index.readUTF8() else {
                return nil
            }

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
        i.validate(for: base.root)
        return base.index(before: i, using: .utf8)
    }

    func index(after i: Rope.Index) -> Rope.Index {
        i.validate(for: base.root)
        return base.index(after: i, using: .utf8)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int) -> Rope.Index {
        i.validate(for: base.root)
        return base.index(i, offsetBy: distance, using: .utf8)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int, limitedBy limit: Rope.Index) -> Rope.Index? {
        i.validate(for: base.root)
        limit.validate(for: base.root)
        return base.index(i, offsetBy: distance, limitedBy: limit, using: .utf8)
    }

    var count: Int {
        base.root.measure(using: .utf8)
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
            i.validate(for: base.root)
            return base.index(roundingDown: i, using: .unicodeScalars)
        }

        subscript(offset: Int) -> UnicodeScalar {
            self[base.index(at: offset, using: .unicodeScalars)]
        }
    }
}

extension Rope.UnicodeScalarView: BidirectionalCollection {
    struct Iterator: IteratorProtocol {
        var index: Rope.Index

        mutating func next() -> Unicode.Scalar? {
            guard let scalar = index.readScalar() else {
                return nil
            }

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
        return base.index(roundingDown: position, using: .unicodeScalars).readScalar()!
    }

    func index(before i: Rope.Index) -> Rope.Index {
        i.validate(for: base.root)
        return base.index(before: i, using: .unicodeScalars)
    }

    func index(after i: Rope.Index) -> Rope.Index {
        i.validate(for: base.root)
        return base.index(after: i, using: .unicodeScalars)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int) -> Rope.Index {
        i.validate(for: base.root)
        return base.index(i, offsetBy: distance, using: .unicodeScalars)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int, limitedBy limit: Rope.Index) -> Rope.Index? {
        i.validate(for: base.root)
        limit.validate(for: base.root)
        return base.index(i, offsetBy: distance, limitedBy: limit, using: .unicodeScalars)
    }

    var count: Int {
        base.root.measure(using: .unicodeScalars)
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
            i.validate(for: base.root)
            return base.index(roundingDown: i, using: .newlines)
        }

        subscript(offset: Int) -> String {
            self[base.index(at: offset, using: .newlines)]
        }
    }
}

extension Rope.LinesView: BidirectionalCollection {
    struct Iterator: IteratorProtocol {
        var index: Rope.Index

        mutating func next() -> String? {
            guard let line = index.readLine() else {
                return nil
            }

            index.next(using: .newlines)
            return line
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
        return base.index(roundingDown: position, using: .newlines).readLine()!
    }

    func index(before i: Rope.Index) -> Rope.Index {
        i.validate(for: base.root)
        return base.index(before: i, using: .newlines)
    }

    func index(after i: Rope.Index) -> Rope.Index {
        i.validate(for: base.root)
        return base.index(after: i, using: .newlines)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int) -> Rope.Index {
        i.validate(for: base.root)
        return base.index(i, offsetBy: distance, using: .newlines)
    }

    func index(_ i: Rope.Index, offsetBy distance: Int, limitedBy limit: Rope.Index) -> Rope.Index? {
        i.validate(for: base.root)
        limit.validate(for: base.root)
        return base.index(i, offsetBy: distance, limitedBy: limit, using: .newlines)
    }

    var count: Int {
        base.root.measure(using: .newlines) + 1
    }
}
