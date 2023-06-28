//
//  Rope.swift
//
//
//  Created by David Albert on 6/21/23.
//

import Foundation

// a rope made out of a B-tree
// internal nodes are order 8: 4...8 children (see Tree.swift)
// leaf nodes are order 1024: 511..<1024 elements (characters), unless it's root, then 0..<1024 (see Chunk.swift)

struct RopeSummary: BTreeSummary {
    var utf16: Int
    var scalars: Int
    var chars: Int
    var newlines: Int

    static func += (left: inout RopeSummary, right: RopeSummary) {
        left.utf16 += right.utf16
        left.scalars += right.scalars
        left.chars += right.chars
        left.newlines += right.newlines
    }

    static var zero: RopeSummary {
        RopeSummary()
    }

    init() {
        self.utf16 = 0
        self.scalars = 0
        self.chars = 0
        self.newlines = 0
    }

    init(summarizing chunk: Chunk) {
        self.utf16 = chunk.countUTF16()
        self.scalars = chunk.countScalars()
        self.chars = chunk.countChars()
        self.newlines = chunk.countNewlines()
    }
}

typealias Rope = BTree<RopeSummary>

extension Rope: Sequence {
    struct Iterator: IteratorProtocol {
        var index: Index

        mutating func next() -> UTF8.CodeUnit? {
            // TODO: implement
            return nil
        }
    }

    func makeIterator() -> Iterator {
        Iterator(index: Index(startOf: root))
    }
}

extension Rope.Index {
    func prevUnicodeScalar() -> Unicode.Scalar? {
        nil
    }

    func nextUnicodeScalar() -> Unicode.Scalar? {
        nil
    }

    func prevChar() -> Character? {
        nil
    }

    func nextChar() -> Character? {
        nil
    }
}

// TODO: audit Collection, BidirectionalCollection and RangeReplaceableCollection for performance.
// Specifically, we know the following methods could be more efficient:
//
// - formIndex(_:offsetBy:)
// - formIndex(_:offsetBy:limitedBy:)
// - index(_:offsetBy:)           -- might not be necessary if we implement the above
// - index(_:offsetBy:limitedBy:) -- ditto
extension Rope: Collection {
    var startIndex: Index {
        Index(startOf: root)
    }
    
    var endIndex: Index {
        Index(endOf: root)
    }
    
    subscript(position: Index) -> UTF8.CodeUnit {
        position.validate(for: root)
        let (chunk, offset) = position.read()!
        return chunk.string.utf8[chunk.string.utf8Index(at: offset)]
    }

    func index(after i: Index) -> Index {
        var i = i
        formIndex(after: &i)
        return i
    }

    func formIndex(after i: inout Index) {
        i.validate(for: root)
        i.formSuccessor()
    }
}

extension Rope: BidirectionalCollection {
    func index(before i: Index) -> Index {
        var i = i
        formIndex(before: &i)
        return i
    }

    func formIndex(before i: inout Index) {
        i.validate(for: root)
    }
}

extension Rope: RangeReplaceableCollection {
    mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C: Collection, C.Element == Element {
        subrange.lowerBound.validate(for: root)
        subrange.upperBound.validate(for: root)
        
        var b = Builder()
        b.push(&root, slicedBy: Range(startIndex..<subrange.lowerBound))
        // TODO: fix this once we have metrics
        // b.push(string: newElements)
        b.push(utf8: newElements)
        b.push(&root, slicedBy: Range(subrange.upperBound..<endIndex))
        self.root = b.build()
    }

    // The deafult implementation calls append(_:) in a loop. This should be faster.
    mutating func append<S>(contentsOf newElements: S) where S : Sequence, S.Element == Element {
        var b = Builder()
        b.push(&root)
        // TODO: fix this once we have metrics
        b.push(utf8: newElements)
        self.root = b.build()
    }

    // override the default behavior
    mutating func reserveCapacity(_ n: Int) {
        // no-op
    }
}

extension Rope {
    subscript(offset: Int) -> UTF8.CodeUnit {
        let i = Index(offsetBy: offset, in: root)
        return self[i]
    }
}

//extension Rope {
//    mutating func append(_ string: String) {
//        append(contentsOf: string)
//    }
//}

extension Rope.Builder {
    mutating func push(string: some Sequence<Character>) {
        var string = String(string)
        string.makeContiguousUTF8()

        var s = string[...]

        while !s.isEmpty {
            let n = s.utf8.count

            if n <= Chunk.maxSize {
                push(leaf: Chunk(s))
                s = s[s.endIndex...]
            } else {
                let i: String.Index
                if n > Chunk.maxSize {
                    let minSplit = Chunk.minSize
                    let maxSplit = Swift.min(Chunk.maxSize, n - Chunk.minSize)

                    let nl = UInt8(ascii: "\n")
                    let lineBoundary = s.withUTF8 { buf in
                        buf[(minSplit-1)..<maxSplit].lastIndex(of: nl)
                    }

                    let offset = lineBoundary ?? maxSplit
                    let codepoint = s.utf8Index(at: offset)
                    // TODO: this is SPI. Hopefully it gets exposed soon.
                    i = s.unicodeScalars._index(roundingDown: codepoint)
                } else {
                    i = s.endIndex
                }

                push(leaf: Chunk(s[..<i]))
                s = s[i...]
            }
        }
    }

    mutating func push(utf8 codeUnits: some Sequence<UTF8.CodeUnit>) {
        push(string: String(bytes: codeUnits, encoding: .utf8)!)
    }
}


// The base metric, which measures UTF-8 code units.
struct UTF8Metric: BTreeMetric {
    func measure(summary: RopeSummary, count: Int) -> Int {
        count
    }
    
    func convertToBaseUnits(_ measuredUnits: Int, in leaf: Chunk) -> Int {
        measuredUnits
    }
    
    func convertToMeasuredUnits(_ baseUnits: Int, in leaf: Chunk) -> Int {
        baseUnits
    }
    
    func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
        offset >= 0 && offset < chunk.count
    }
    
    func prev(_ offset: Int, in chunk: Chunk) -> Int? {
        if offset == 0 {
            return nil
        } else {
            return offset - 1
        }
    }
    
    func next(_ offset: Int, in chunk: Chunk) -> Int? {
        if offset == chunk.count {
            return nil
        } else {
            return offset + 1
        }
    }

    var canFragment: Bool {
        false
    }
}

extension BTreeMetric<RopeSummary> where Self == UTF8Metric {
    static var utf8: UTF8Metric { UTF8Metric() }
}

struct UnicodeScalarMetric: BTreeMetric {
    func measure(summary: RopeSummary, count: Int) -> Int {
        summary.scalars
    }
    
    func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk) -> Int {
        let startIndex = chunk.string.startIndex

        let i = chunk.string.unicodeScalarIndex(at: measuredUnits)
        return chunk.string.utf8.distance(from: startIndex, to: i)
    }
    
    func convertToMeasuredUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
        let startIndex = chunk.string.startIndex
        let i = chunk.string.utf8Index(at: baseUnits)

        assert(chunk.string.isValidUnicodeScalarIndex(i))

        return chunk.string.unicodeScalars.distance(from: startIndex, to: i)
    }
    
    func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
        let i = chunk.string.utf8Index(at: offset)
        return chunk.string.isValidUnicodeScalarIndex(i)
    }
    
    func prev(_ offset: Int, in chunk: Chunk) -> Int? {
        if offset == 0 {
            return nil
        }

        let startIndex = chunk.string.startIndex
        let current = chunk.string.utf8Index(at: offset)

        let target = chunk.string.unicodeScalars.index(before: current)
        return chunk.string.utf8.distance(from: startIndex, to: target)
    }
    
    func next(_ offset: Int, in chunk: Chunk) -> Int? {
        if offset == chunk.count {
            return nil
        }

        let startIndex = chunk.string.startIndex
        let current = chunk.string.utf8Index(at: offset)

        let target = chunk.string.unicodeScalars.index(after: current)
        return chunk.string.utf8.distance(from: startIndex, to: target)
    }

    var canFragment: Bool {
        false
    }
}

extension BTreeMetric<RopeSummary> where Self == UnicodeScalarMetric {
    static var unicodeScalars: UnicodeScalarMetric { UnicodeScalarMetric() }
}

struct CharacterMetric: BTreeMetric {
    func measure(summary: RopeSummary, count: Int) -> Int {
        summary.chars
    }
    
    func convertToBaseUnits(_ measuredUnits: Int, in leaf: Chunk) -> Int {
        0
    }
    
    func convertToMeasuredUnits(_ baseUnits: Int, in leaf: Chunk) -> Int {
        0
    }
    
    func isBoundary(_ offset: Int, in leaf: Chunk) -> Bool {
        false
    }
    
    func prev(_ offset: Int, in leaf: Chunk) -> Int? {
        nil
    }
    
    func next(_ offset: Int, in leaf: Chunk) -> Int? {
        nil
    }

    var canFragment: Bool {
        true
    }
}

extension BTreeMetric<RopeSummary> where Self == CharacterMetric {
    static var characters: CharacterMetric { CharacterMetric() }
}
