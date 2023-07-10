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

typealias Rope = BTree<RopeSummary>

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
    static var defaultMetric: Rope.UTF8Metric { Rope.UTF8Metric() }
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

extension Rope.Index: CustomStringConvertible {
    var description: String {
        "\(position)[utf8]"
    }
}

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

        var old = GraphemeBreaker(for: self, upTo: start)
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

        var old = GraphemeBreaker(for: self, upTo: subrange.upperBound, withKnownNextScalar: subrange.upperBound.position == root.count ? nil : unicodeScalars[subrange.upperBound])
        var new = GraphemeBreaker(for: self, upTo: subrange.lowerBound, withKnownNextScalar: newElements.first?.unicodeScalars.first)

        var b = Builder()
        b.push(&root, slicedBy: Range(startIndex..<subrange.lowerBound))
        b.push(string: newElements, breaker: &new)

        var rest = Rope(self, slicedBy: Range(subrange.upperBound..<endIndex))
        rest.resyncBreaks(old: &old, new: &new)
        b.push(&rest.root)

        self.root = b.build()
    }

    // The deafult implementation calls append(_:) in a loop. This should be faster.
    mutating func append<S>(contentsOf newElements: S) where S : Sequence, S.Element == Element {
        var b = Builder()
        var br = GraphemeBreaker(for: self, upTo: endIndex)

        b.push(&root)
        b.push(string: newElements, breaker: &br)
        self.root = b.build()
    }
}

extension Rope {
    func index(at offset: Int) -> Index {
        Index(offsetBy: offset, in: root)
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

// This should really be in an extension of Rope, not BTree, but if I do
// that, lldb gives the following error when printing GraphemeBreaker or
// other types that embed it:
//
//   (lldb) expr Rope.GraphemeBreaker()
//   error: Couldn't materialize: can't get size of type "Rope.BTree<Rope.RopeSummary>< where τ_0_0 == Rope.RopeSummary>.GraphemeBreaker"
//   error: errored out in DoExecute, couldn't PrepareToExecuteJITExpression
extension BTree {
    struct GraphemeBreaker: Equatable {
        #if swift(<5.9)
        static func == (lhs: BTree<Summary>.GraphemeBreaker, rhs: BTree<Summary>.GraphemeBreaker) -> Bool {
            false
        }
        #endif

        var recognizer: Unicode._CharacterRecognizer

        init(_ recognizer: Unicode._CharacterRecognizer = Unicode._CharacterRecognizer(), consuming s: Substring? = nil) {
            self.recognizer = recognizer

            if let s {
                consume(s)
            }
        }

        // assumes upperBound is valid in rope
        init(for rope: Rope, upTo upperBound: Rope.Index, withKnownNextScalar next: Unicode.Scalar? = nil) {
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

            let (chunk, offset) = upperBound.read()!
            let i = chunk.string.utf8Index(at: offset)

            if i <= chunk.firstBreak {
                self.init(chunk.breaker.recognizer, consuming: chunk.string[..<i])
                return
            }

            let prev = chunk.characters.index(before: i)

            self.init(consuming: chunk.string[prev..<i])
        }

        mutating func hasBreak(before next: Unicode.Scalar) -> Bool {
            recognizer.hasBreak(before: next)
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

        mutating func consume(_ s: Substring) {
            for u in s.unicodeScalars {
                _ = recognizer.hasBreak(before: u)
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

            push(leaf: Chunk(string[i..<end], breaker: &breaker))
            i = end
        }
    }
}

// It would be better if these metrics were nested inside Rope instead
// of BTree, but that causes problems with LLDB – I get errors like
// "error: cannot find 'metric' in scope" in response to 'p metric'.
//
// Ditto for using `some BTreeMetric<Summary>` instead of introducing
// a generic type and constrainting it to BTreeMetric<Summary>.
extension BTree {
    // The base metric, which measures UTF-8 code units.
    struct UTF8Metric: BTreeMetric {
        func measure(summary: RopeSummary, count: Int) -> Int {
            count
        }
        
        func convertToBaseUnits(_ measuredUnits: Int, in leaf: Chunk) -> Int {
            measuredUnits
        }
        
        func convertFromBaseUnits(_ baseUnits: Int, in leaf: Chunk) -> Int {
            baseUnits
        }
        
        func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
            true
        }
        
        func prev(_ offset: Int, in chunk: Chunk) -> Int? {
            assert(offset > 0)
            return offset - 1
        }
        
        func next(_ offset: Int, in chunk: Chunk) -> Int? {
            assert(offset < chunk.count)
            return offset + 1
        }
        
        var canFragment: Bool {
            false
        }
        
        var type: Rope.MetricType {
            .trailing
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.UTF8Metric {
    static var utf8: Rope.UTF8Metric { Rope.UTF8Metric() }
}

extension BTree {
    struct UTF16Metric: BTreeMetric {
        func measure(summary: RopeSummary, count: Int) -> Int {
            summary.utf16
        }
        
        func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk) -> Int {
            fatalError("not implemented")
        }
        
        func convertFromBaseUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
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
        
        var type: Rope.MetricType {
            .trailing
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.UTF16Metric {
    static var utf16: Rope.UTF16Metric { Rope.UTF16Metric() }
}

extension BTree {
    struct UnicodeScalarMetric: BTreeMetric {
        func measure(summary: RopeSummary, count: Int) -> Int {
            summary.scalars
        }
        
        func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk) -> Int {
            let startIndex = chunk.string.startIndex
            
            let i = chunk.string.unicodeScalarIndex(at: measuredUnits)
            return chunk.string.utf8.distance(from: startIndex, to: i)
        }
        
        func convertFromBaseUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
            let startIndex = chunk.string.startIndex
            let i = chunk.string.utf8Index(at: baseUnits)

            return chunk.string.unicodeScalars.distance(from: startIndex, to: i)
        }
        
        func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
            let i = chunk.string.utf8Index(at: offset)
            return chunk.isValidUnicodeScalarIndex(i)
        }
        
        func prev(_ offset: Int, in chunk: Chunk) -> Int? {
            assert(offset > 0)
            
            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            let target = chunk.string.unicodeScalars.index(before: current)
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }
        
        func next(_ offset: Int, in chunk: Chunk) -> Int? {
            assert(offset < chunk.count)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            let target = chunk.string.unicodeScalars.index(after: current)
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }
        
        var canFragment: Bool {
            false
        }
        
        var type: Rope.MetricType {
            .trailing
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.UnicodeScalarMetric {
    static var unicodeScalars: Rope.UnicodeScalarMetric { Rope.UnicodeScalarMetric() }
}

extension BTree {
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
        
        func convertFromBaseUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
            let startIndex = chunk.characters.startIndex
            let i = chunk.string.utf8Index(at: baseUnits)
            
            return chunk.characters.distance(from: startIndex, to: i)
        }
        
        func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
            // The only time offset will equal chunk.count is
            // when chunk is the last offset of the rope.
            if offset == chunk.count {
                return true
            }
            
            if offset < chunk.prefixCount || offset > chunk.count - chunk.suffixCount {
                return false
            }
            
            let i = chunk.string.utf8Index(at: offset)
            return chunk.isValidCharacterIndex(i)
        }
        
        func prev(_ offset: Int, in chunk: Chunk) -> Int? {
            assert(offset > 0)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            if current <= chunk.firstBreak {
                return nil
            }
            
            let target = chunk.string.index(before: current)
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }
        
        func next(_ offset: Int, in chunk: Chunk) -> Int? {
            assert(offset < chunk.count)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            if current >= chunk.lastBreak {
                return nil
            }
            
            let target = chunk.string.index(after: current)
            return chunk.string.utf8.distance(from: startIndex, to: target)
        }
        
        var canFragment: Bool {
            true
        }
        
        var type: Rope.MetricType {
            .trailing
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.CharacterMetric {
    static var characters: Rope.CharacterMetric { Rope.CharacterMetric() }
}

extension BTree {
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
                    offset = buf[offset...].firstIndex(of: nl)! + 1
                    count += 1
                }
            }
            
            return offset
        }
        
        func convertFromBaseUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
            return chunk.string.withExistingUTF8 { buf in
                Chunk.countNewlines(in: buf[..<baseUnits])
            }
        }
        
        func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
            assert(offset > 0)
            
            return chunk.string.withExistingUTF8 { buf in
                buf[offset - 1] == UInt8(ascii: "\n")
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
            assert(offset < chunk.count)

            let nl = UInt8(ascii: "\n")
            return chunk.string.withExistingUTF8 { buf in
                buf[offset...].firstIndex(of: nl).map { $0 + 1 }
            }
        }
        
        var canFragment: Bool {
            true
        }
        
        var type: Rope.MetricType {
            .trailing
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.NewlinesMetric {
    static var newlines: Rope.NewlinesMetric { Rope.NewlinesMetric() }
}
