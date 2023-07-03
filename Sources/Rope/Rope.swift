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

extension RopeSummary: BTreeDefaultMetric {
    static var defaultMetric: UTF8Metric { UTF8Metric() }
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
        assert(chunk.isValidUTF16Index(i))

        return chunk.string.utf16[i]
    }

    func readScalar() -> Unicode.Scalar? {
        guard let (chunk, offset) = read() else {
            return nil
        }

        let i = chunk.string.utf8Index(at: offset)
        assert(chunk.isValidUnicodeScalarIndex(i))

        return chunk.string.unicodeScalars[i]
    }

    func readChar() -> Character? {
        guard let (chunk, offset) = read() else {
            return nil
        }

        let i = chunk.string.utf8Index(at: offset)

        assert(i >= chunk.firstBreak && i <= chunk.lastBreak)
        assert(chunk.isValidCharacterIndex(i))

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

// TODO: audit default methods from Collection, BidirectionalCollection and RangeReplaceableCollection for performance.
extension Rope: Collection {
    var count: Int {
        root.measure(using: .characters)
    }

    var startIndex: Index {
        Index(startOf: root)
    }
    
    var endIndex: Index {
        Index(endOf: root)
    }
    
    subscript(position: Index) -> Character {
        position.validate(for: root)
        let position = index(roundingDown: position)
        return position.readChar()!
    }

    subscript(bounds: Range<Index>) -> Rope {
        bounds.lowerBound.validate(for: root)
        bounds.upperBound.validate(for: root)

        let start = index(roundingDown: bounds.lowerBound)
        let end = index(roundingDown: bounds.upperBound)

        var sliced = Rope(self, slicedBy: Range(start..<end))

        var old = GraphemeBreaker(in: self, upTo: start)
        var new = GraphemeBreaker()
        sliced.resyncBreaks(old: &old, new: &new)

        return sliced
    }

    func index(after i: Index) -> Index {
        index(after: i, using: .characters)
    }

    func index(_ i: Index, offsetBy distance: Int) -> Index {
        index(i, offsetBy: distance, using: .characters)
    }

    func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        index(i, offsetBy: distance, limitedBy: limit, using: .characters)
    }
}

extension Rope: BidirectionalCollection {
    func index(before i: Index) -> Index {
        index(before: i, using: .characters)
    }
}

extension Rope: RangeReplaceableCollection {
    mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C: Collection, C.Element == Element {
        subrange.lowerBound.validate(for: root)
        subrange.upperBound.validate(for: root)

        let subrange = index(roundingDown: subrange.lowerBound)..<index(roundingDown: subrange.upperBound)

        var old = GraphemeBreaker(...)
        var new = GraphemeBreaker(in: self, upTo: subrange.lowerBound, withKnownNextScalar: newElements.first?.unicodeScalars.first)

        var b = Builder()
        b.push(&root, slicedBy: Range(startIndex..<subrange.lowerBound))
        b.push(string: newElements, breaker: &new)

        var rest = Rope(self, slicedBy: Range(subrange.upperBound..<endIndex))
        rest.resyncBreaks(old: &old, new: &new)
        b.push(&rest.root, slicedBy: Range(subrange.upperBound..<endIndex))

        self.root = b.build()
    }

    // The deafult implementation calls append(_:) in a loop. This should be faster.
    mutating func append<S>(contentsOf newElements: S) where S : Sequence, S.Element == Element {
        var b = Builder()
        b.push(&root)
        b.push(string: newElements)
        self.root = b.build()
    }
}

extension Rope {
    subscript(offset: Int) -> Character {
        let i = Index(offsetBy: offset, in: root)
        return self[i]
    }

    func index(roundingDown i: Index) -> Index {
        index(roundingDown: i, using: .characters)
    }
}

extension Rope {
    mutating func append(_ string: String) {
        append(contentsOf: string)
    }
}

extension Rope {
    struct GraphemeBreaker {
        var recognizer: Unicode._CharacterRecognizer

        init() {
            recognizer = Unicode._CharacterRecognizer()
        }

        init(_ recognizer: Unicode._CharacterRecognizer) {
            self.recognizer = recognizer
        }

        // assumes upperBound is valid in rope
        init(in rope: Rope, upTo upperBound: Rope.Index, withKnownNextScalar next: Unicode.Scalar? = nil) {
            assert(upperBound.isBoundary(in: .unicodeScalars))

            if rope.isEmpty || upperBound.position == 0 {
                self.init()
                return
            }

            if let next {
                let i = rope.unicodeScalars.index(before: upperBound)
                let prev = rope.unicodeScalars[i]

                if Unicode._CharacterRecognizer.quickBreak(between: prev, and: next) ?? false {
                    self.init()
                    return
                }
            }

            var i = rope.index(roundingDown: upperBound, using: .characters)

            if i == upperBound {
                self.init()
                return
            }

            var r = Unicode._CharacterRecognizer()
            while i < upperBound {
                let b = r.hasBreak(before: rope.unicodeScalars[i])
                assert(!b)
                rope.unicodeScalars.formIndex(after: &i)
            }

            self.init(r)
        }

        mutating func firstBreak(in s: Substring) -> Range<String.Index>? {
            let r = s.withExistingUTF8 { buf in
                recognizer._firstBreak(inUncheckedUnsafeUTF8Buffer: buf)
            }

            if let r {
                return s.utf8Index(at: r.lowerBound)..<s.utf8Index(at: r.upperBound)
            } else {
                return nil
            }
        }
    }
}

extension Rope {
    mutating func resyncBreaks(old: inout GraphemeBreaker, new: inout GraphemeBreaker) {
        var b = Builder()

        var i = startIndex
        while var (chunk, _) = i.read() {
            let done = chunk.resyncBreaks(old: &old, new: &new)
            b.push(leaf: chunk)
            i.nextLeaf()

            if done {
                break
            }
        }

        b.push(&root, slicedBy: i.position..<root.count)
        root = b.build()
    }
}

extension Rope.Builder {
    mutating func push(string: some Sequence<Character>, breaker: inout Rope.GraphemeBreaker) {
        var string = String(string)
        string.makeContiguousUTF8()

        var i = string.startIndex

        while i < string.endIndex {
            let n = string.utf8.distance(from: i, to: string.endIndex)

            let end: String.Index
            if n <= Chunk.maxSize {
                end = string.endIndex
            } else {
                end = Chunk.boundaryForBulkInsert(string[i...])
            }

            var s = string[i..<end]

            guard let r = breaker.firstBreak(in: s) else {
                // uncommon, no character boundaries
                let c = s.utf8.count
                push(leaf: Chunk(s[..<end], prefixCount: c, suffixCount: c))
                continue
            }

            let first = r.lowerBound
            s = s[r.upperBound...]

            var last = first
            while let r = breaker.firstBreak(in: s) {
                last = r.lowerBound
                s = s[r.upperBound...]
            }

            let prefixCount = string.utf8.distance(from: i, to: first)
            let suffixCount = string.utf8.distance(from: last, to: end)

            push(leaf: Chunk(string[i..<end], prefixCount: prefixCount, suffixCount: suffixCount))
            i = end
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

        assert(chunk.isValidUnicodeScalarIndex(i))

        return chunk.string.unicodeScalars.distance(from: startIndex, to: i)
    }
    
    func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
        let i = chunk.string.utf8Index(at: offset)
        return chunk.isValidUnicodeScalarIndex(i)
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

        assert(chunk.isValidCharacterIndex(i))
        assert(measuredUnits < chunk.characters.count)

        return chunk.prefixCount + chunk.string.utf8.distance(from: startIndex, to: i)
        
    }
    
    func convertToMeasuredUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
        let startIndex = chunk.characters.startIndex
        let i = chunk.string.utf8Index(at: baseUnits)

        assert(chunk.isValidCharacterIndex(i))

        return chunk.characters.distance(from: startIndex, to: i)
    }

    // TODO: make sure this metric works with position == 0. I think it does.
    // Also make sure it works with offset == chunk.count, which happens
    // for offsetInLeaf == 0 for other chunks.
    func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
        if offset < chunk.prefixCount || offset > chunk.suffixCount {
            return false
        }

        let i = chunk.string.utf8Index(at: offset)
        return chunk.isValidCharacterIndex(i)
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

struct NewlinesMetric: BTreeMetric {
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

extension BTreeMetric<RopeSummary> where Self == NewlinesMetric {
    static var newlines: NewlinesMetric { NewlinesMetric() }
}
