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

        mutating func next() -> Character? {
            let c = index.readChar()
            index.next(using: .characters)
            return c
        }
    }

    func makeIterator() -> Iterator {
        Iterator(index: Index(startOf: root))
    }
}

extension Rope.Index {
    func readUTF8() -> UTF8.CodeUnit? {
        guard let (chunk, offset) = read() else {
            return nil
        }

        return chunk.string.utf8[chunk.string.utf8Index(at: offset)]
    }

    func readUTF16() -> UTF16.CodeUnit? {
        guard let (chunk, offset) = read() else {
            return nil
        }

        let i = chunk.string.utf8Index(at: offset)
        assert(chunk.string.isValidUTF16Index(i))

        return chunk.string.utf16[i]
    }

    func readScalar() -> Unicode.Scalar? {
        guard let (chunk, offset) = read() else {
            return nil
        }

        let i = chunk.string.utf8Index(at: offset)
        assert(chunk.string.isValidUnicodeScalarIndex(i))

        return chunk.string.unicodeScalars[i]
    }

    func readChar() -> Character? {
        guard let (chunk, offset) = read() else {
            return nil
        }

        let i = chunk.string.utf8Index(at: offset)

        assert(i >= chunk.firstBreak && i <= chunk.lastBreak)
        assert(chunk.string.isValidCharacterIndex(i))

        if chunk.suffixCount == 0 || i < chunk.lastBreak {
            // the common case, the full character is in this chunk
            return chunk.string[i]
        }

        // the character is split across chunks
        var s = chunk.string[chunk.lastBreak...]

        guard let (nextChunk, nextOffset) = peekNextLeaf() else {
            // We have an incomplete grapheme cluster at the end of the
            // the rope. This is uncommon. For example, imagine a rope
            // that ends with a zero-width joiner.

            assert(s.count == 1)
            return s[s.startIndex]
        }

        assert(nextOffset == 0)
        s += nextChunk.string[..<nextChunk.firstBreak]

        assert(s.count == 1)
        return s[s.startIndex]
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
    
    subscript(position: Index) -> Character {
        position.validate(for: root)
        let (chunk, offset) = position.read()!
        return chunk.string[chunk.string.utf8Index(at: offset)]
    }

    subscript(bounds: Range<Index>) -> Rope {
        bounds.lowerBound.validate(for: root)
        bounds.upperBound.validate(for: root)

        var r = root

        var b = Builder()
        b.push(&r, slicedBy: Range(bounds))
        return Rope(b.build())
    }

    func index(after i: Index) -> Index {
        var i = i
        formIndex(after: &i)
        return i
    }

    func formIndex(after i: inout Index) {
        i.validate(for: root)
        i.next(using: .characters)
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
        i.prev(using: .characters)
    }
}

extension Rope: RangeReplaceableCollection {
    mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C: Collection, C.Element == Element {
        subrange.lowerBound.validate(for: root)
        subrange.upperBound.validate(for: root)
        
        var b = Builder()
        b.push(&root, slicedBy: Range(startIndex..<subrange.lowerBound))
        b.push(string: newElements)
        b.push(&root, slicedBy: Range(subrange.upperBound..<endIndex))
        self.root = b.build()
    }

    // The deafult implementation calls append(_:) in a loop. This should be faster.
    mutating func append<S>(contentsOf newElements: S) where S : Sequence, S.Element == Element {
        var b = Builder()
        b.push(&root)
        b.push(string: newElements)
        self.root = b.build()
    }

    // override the default behavior
    mutating func reserveCapacity(_ n: Int) {
        // no-op
    }
}

extension Rope {
    subscript(offset: Int) -> Character {
        let i = Index(offsetBy: offset, in: root)
        return self[i]
    }
}

extension Rope {
    mutating func append(_ string: String) {
        append(contentsOf: string)
    }
}

extension Rope.Builder {
    mutating func push(string: some Sequence<Character>) {
        var string = String(string)
        string.makeContiguousUTF8()

        var s = string[...]

        while !s.isEmpty {
            let n = s.utf8.count

            if n <= Chunk.maxSize {
                // TODO: prefixCount, suffixCount
                push(leaf: Chunk(s, prefixCount: 0, suffixCount: 0))
                s = s[s.endIndex...]
            } else {
                let i: String.Index
                if n > Chunk.maxSize {
                    let minSplit = Chunk.minSize
                    let maxSplit = Swift.min(Chunk.maxSize, n - Chunk.minSize)

                    let nl = UInt8(ascii: "\n")
                    let lineBoundary = s.withExistingUTF8 { buf in
                        buf[(minSplit-1)..<maxSplit].lastIndex(of: nl)
                    }

                    let offset = lineBoundary ?? maxSplit
                    let codepoint = s.utf8Index(at: offset)
                    // TODO: this is SPI. Hopefully it gets exposed soon.
                    i = s.unicodeScalars._index(roundingDown: codepoint)
                } else {
                    i = s.endIndex
                }

                // TODO: prefixCount, suffixCount
                push(leaf: Chunk(s[..<i], prefixCount: 0, suffixCount: 0))
                s = s[i...]
            }
        }
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

struct UTF16Metric: BTreeMetric {
    func measure(summary: RopeSummary, count: Int) -> Int {
        summary.utf16
    }

    func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk) -> Int {
        fatalError("not implemented")
    }

    func convertToMeasuredUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
        fatalError("not implemented")
    }

    func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
        fatalError("not implemented")
    }

    func prev(_ offset: Int, in chunk: Chunk) -> Int? {
        fatalError("not implemented")
    }

    func next(_ offset: Int, in chunk: Chunk) -> Int? {
        fatalError("not implemented")
    }

    var canFragment: Bool {
        false
    }    
}

extension BTreeMetric<RopeSummary> where Self == UTF16Metric {
    static var utf16: UTF16Metric { UTF16Metric() }
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
    
    func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk) -> Int {
        let startIndex = chunk.characters.startIndex
        let i = chunk.characters.index(startIndex, offsetBy: measuredUnits)

        assert(chunk.string.isValidCharacterIndex(i))
        assert(measuredUnits < chunk.characters.count)

        return chunk.prefixCount + chunk.string.utf8.distance(from: startIndex, to: i)
        
    }
    
    func convertToMeasuredUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
        let startIndex = chunk.characters.startIndex
        let i = chunk.string.utf8Index(at: baseUnits)

        assert(chunk.string.isValidCharacterIndex(i))

        return chunk.characters.distance(from: startIndex, to: i)
    }
    
    func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
        let i = chunk.string.utf8Index(at: offset)
        return chunk.string.isValidCharacterIndex(i)
    }
    
    func prev(_ offset: Int, in chunk: Chunk) -> Int? {
        let current = chunk.string.utf8Index(at: offset)
        if current <= chunk.firstBreak {
            return nil
        }

        let prev = chunk.string.index(before: current)
        return offset - chunk.string.utf8.distance(from: prev, to: current)
    }
    
    func next(_ offset: Int, in chunk: Chunk) -> Int? {
        let current = chunk.string.utf8Index(at: offset)
        if current >= chunk.lastBreak {
            return nil
        }

        let next = chunk.string.index(after: current)
        return offset + chunk.string.utf8.distance(from: current, to: next)
    }

    var canFragment: Bool {
        true
    }
}

extension BTreeMetric<RopeSummary> where Self == CharacterMetric {
    static var characters: CharacterMetric { CharacterMetric() }
}

struct LinesMetric: BTreeMetric {
    func measure(summary: RopeSummary, count: Int) -> Int {
        summary.newlines
    }
    
    func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk) -> Int {
        let nl = UInt8(ascii: "\n")

        var offset = 0
        var count = 0
        chunk.string.withExistingUTF8 { buf in
            while count < measuredUnits {
                offset = buf[offset...].firstIndex(of: nl)!
                count += 1
            }
        }

        return offset
    }
    
    func convertToMeasuredUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
        return chunk.string.withExistingUTF8 { buf in
            Chunk.countNewlines(in: buf[..<baseUnits])
        }
    }
    
    func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
        // TODO: what about the first chunk in the string? Offset 0 there should be a newline because this is a trailing metric.
        if offset == 0 {
            return false
        } else {
            return chunk.string.withExistingUTF8 { buf in
                buf[offset - 1] == UInt8(ascii: "\n")
            }
        }
    }
    
    func prev(_ offset: Int, in chunk: Chunk) -> Int? {
        assert(offset > 0)

        let nl = UInt8(ascii: "\n")
        return chunk.string.withExistingUTF8 { buf in
            buf[..<(offset - 1)].lastIndex(of: nl).map { $0 + 1 }
        }
    }
    
    func next(_ offset: Int, in chunk: Chunk) -> Int? {
        let nl = UInt8(ascii: "\n")
        return chunk.string.withExistingUTF8 { buf in
            buf[offset...].firstIndex(of: nl).map { $0 + 1 }
        }
    }

    var canFragment: Bool {
        true
    }
}

extension BTreeMetric<RopeSummary> where Self == CharacterMetric {
    static var lines: LinesMetric { LinesMetric() }
}
