//
//  Rope.swift
//
//
//  Created by David Albert on 6/21/23.
//

import Foundation

// MARK: - Core data structures


// a rope made out of a B-tree
// internal nodes are order 8: 4...8 children (see BTree.swift)
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
        self.utf16 = chunk.string.utf16.count
        self.scalars = chunk.string.unicodeScalars.count
        self.chars = chunk.characters.count

        self.newlines = chunk.string.withExistingUTF8 { buf in
            countNewlines(in: buf[...])
        }
    }
}

extension RopeSummary: BTreeDefaultMetric {
    static var defaultMetric: Rope.UTF8Metric { Rope.UTF8Metric() }
}


struct Chunk: BTreeLeaf {
    // measured in base units
    static let minSize = 511
    static let maxSize = 1023

    static var zero: Chunk {
        Chunk()
    }

    var string: String
    var prefixCount: Int
    var suffixCount: Int

    // a breaker ready to consume the first
    // scalar in the Chunk. Used for prefix/suffix
    // calculation in pushMaybeSplitting(other:)
    var breaker: Rope.GraphemeBreaker

    var count: Int {
        string.utf8.count
    }

    var isUndersized: Bool {
        count < Chunk.minSize
    }

    var firstBreak: String.Index {
        string.utf8Index(at: prefixCount)
    }

    var lastBreak: String.Index {
        string.utf8Index(at: count - suffixCount)
    }

    var characters: Substring {
        string[firstBreak...]
    }

    init() {
        self.string = ""
        self.prefixCount = 0
        self.suffixCount = 0
        self.breaker = Rope.GraphemeBreaker()
    }

    init(_ substring: Substring, breaker b: inout Rope.GraphemeBreaker) {
        let s = String(substring)
        assert(s.isContiguousUTF8)
        assert(s.utf8.count <= Chunk.maxSize)

        // save the breaker at the start of the chunk
        self.breaker = b

        self.string = s
        (self.prefixCount, self.suffixCount) = calculateBreaks(in: s, using: &b)
    }

    mutating func pushMaybeSplitting(other: Chunk) -> Chunk? {
        string += other.string
        var b = breaker

        if string.utf8.count <= Chunk.maxSize {
            (prefixCount, suffixCount) = calculateBreaks(in: string, using: &b)
            return nil
        } else {
            let i = boundaryForMerge(string[...])

            let rest = String(string.unicodeScalars[i...])
            string = String(string.unicodeScalars[..<i])

            (prefixCount, suffixCount) = calculateBreaks(in: string, using: &b)
            return Chunk(rest[...], breaker: &b)
        }
    }

    subscript(bounds: Range<Int>) -> Chunk {
        let start = string.utf8Index(at: bounds.lowerBound).samePosition(in: string.unicodeScalars)
        let end = string.utf8Index(at: bounds.upperBound).samePosition(in: string.unicodeScalars)

        guard let start, let end else {
            fatalError("invalid unicode scalar offsets")
        }

        var b = breaker
        b.consume(string[string.startIndex..<start])
        return Chunk(string[start..<end], breaker: &b)
    }

    func isValidUnicodeScalarIndex(_ i: String.Index) -> Bool {
        i.samePosition(in: string.unicodeScalars) != nil
    }

    func isValidCharacterIndex(_ i: String.Index) -> Bool {
        i == characters._index(roundingDown: i)
    }
}

fileprivate func calculateBreaks(in string: String, using breaker: inout Rope.GraphemeBreaker) -> (prefixCount: Int, suffixCount: Int) {
    var s = string[...]

    guard let r = breaker.firstBreak(in: s) else {
        // uncommon, no character boundaries
        let c = s.utf8.count
        return (c, c)
    }

    let first = r.lowerBound
    s = s[r.upperBound...]

    var last = r.lowerBound
    while let r = breaker.firstBreak(in: s) {
        last = r.lowerBound
        s = s[r.upperBound...]
    }

    let prefixCount = string.utf8.distance(from: string.startIndex, to: first)
    let suffixCount = string.utf8.distance(from: last, to: string.endIndex)

    return (prefixCount, suffixCount)
}


// MARK: - Metrics


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

        var type: BTreeMetricType {
            .atomic
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.UTF8Metric {
    static var utf8: Rope.UTF8Metric { Rope.UTF8Metric() }
}

// Rope doesn't have a true UTF-16 view like String does. Instead the
// UTF16Metric is mostly useful for counting UTF-16 code units. Its
// prev and next operate the same as UnicodeScalarMetric. Next() and prev()
// will "skip" trailing surrogates, jumping to the next Unicode scalar
// boundary. "Skip" is in quotes because there are not actually any leading
// or trailing surrogates in Rope's storage. It's just Unicode scalars that
// are encoded as UTF-8.
extension BTree {
    struct UTF16Metric: BTreeMetric {
        func measure(summary: RopeSummary, count: Int) -> Int {
            summary.utf16
        }

        func convertToBaseUnits(_ measuredUnits: Int, in chunk: Chunk) -> Int {
            let startIndex = chunk.string.startIndex

            let i = chunk.string.utf16Index(at: measuredUnits)
            return chunk.string.utf8.distance(from: startIndex, to: i)
        }

        func convertFromBaseUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
            let startIndex = chunk.string.startIndex
            let i = chunk.string.utf8Index(at: baseUnits)

            return chunk.string.utf16.distance(from: startIndex, to: i)
        }

        func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
            let i = chunk.string.utf8Index(at: offset)
            return chunk.isValidUnicodeScalarIndex(i)
        }

        func prev(_ offset: Int, in chunk: Chunk) -> Int? {
            assert(offset > 0)

            let startIndex = chunk.string.startIndex
            let current = chunk.string.utf8Index(at: offset)

            var target = chunk.string.unicodeScalars._index(roundingDown: current)
            if target == current {
                target = chunk.string.unicodeScalars.index(before: target)
            }
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

        var type: BTreeMetricType {
            .atomic
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

            var target = chunk.string.unicodeScalars._index(roundingDown: current)
            if target == current {
                target = chunk.string.unicodeScalars.index(before: target)
            }
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

        var type: BTreeMetricType {
            .atomic
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
            assert(measuredUnits <= chunk.characters.count)

            let startIndex = chunk.characters.startIndex
            let i = chunk.characters.index(startIndex, offsetBy: measuredUnits)

            assert(chunk.isValidCharacterIndex(i))

            return chunk.prefixCount + chunk.string.utf8.distance(from: startIndex, to: i)
        }

        func convertFromBaseUnits(_ baseUnits: Int, in chunk: Chunk) -> Int {
            let startIndex = chunk.characters.startIndex
            let i = chunk.string.utf8Index(at: baseUnits)

            return chunk.characters.distance(from: startIndex, to: i)
        }

        func isBoundary(_ offset: Int, in chunk: Chunk) -> Bool {
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

            var target = chunk.string._index(roundingDown: current)
            if target == current {
                target = chunk.string.index(before: target)
            }

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

        var type: BTreeMetricType {
            .atomic
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
                countNewlines(in: buf[..<baseUnits])
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

        var type: BTreeMetricType {
            .trailing
        }
    }
}

extension BTreeMetric<RopeSummary> where Self == Rope.NewlinesMetric {
    static var newlines: Rope.NewlinesMetric { Rope.NewlinesMetric() }
}


// MARK: - Builder additions


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
                end = boundaryForBulkInsert(string[i...])
            }

            push(leaf: Chunk(string[i..<end], breaker: &breaker))
            i = end
        }
    }
}


fileprivate func boundaryForBulkInsert(_ s: Substring) -> String.Index {
    boundary(for: s, startingAt: Chunk.minSize)
}

fileprivate func boundaryForMerge(_ s: Substring) -> String.Index {
    // for the smallest chunk that needs splitting (n = maxSize + 1 = 1024):
    // minSplit = max(511, 1024 - 1023) = max(511, 1) = 511
    // maxSplit = min(1023, 1024 - 511) = min(1023, 513) = 513
    boundary(for: s, startingAt: max(Chunk.minSize, s.utf8.count - Chunk.maxSize))
}

fileprivate func boundary(for s: Substring, startingAt minSplit: Int) -> String.Index {
    let maxSplit = min(Chunk.maxSize, s.utf8.count - Chunk.minSize)

    let nl = UInt8(ascii: "\n")
    let lineBoundary = s.withExistingUTF8 { buf in
        buf[(minSplit-1)..<maxSplit].lastIndex(of: nl)
    }

    let offset = lineBoundary ?? maxSplit
    let i = s.utf8Index(at: offset)
    return s.unicodeScalars._index(roundingDown: i)
}


// MARK: - Index additions


extension Rope.Index {
    func readUTF8() -> UTF8.CodeUnit? {
        guard let (chunk, offset) = read() else {
            return nil
        }

        if offset == chunk.count {
            // We're at the end of the rope
            return nil
        }

        return chunk.string.utf8[chunk.string.utf8Index(at: offset)]
    }

    func readScalar() -> Unicode.Scalar? {
        guard let (chunk, offset) = read() else {
            return nil
        }

        if offset == chunk.count {
            // We're at the end of the rope
            return nil
        }

        let i = chunk.string.utf8Index(at: offset)
        assert(chunk.isValidUnicodeScalarIndex(i))

        return chunk.string.unicodeScalars[i]
    }

    func readChar() -> Character? {
        guard var (chunk, offset) = read() else {
            return nil
        }

        if offset == chunk.count {
            // We're at the end of the rope
            return nil
        }

        let ci = chunk.string.utf8Index(at: offset)

        assert(ci >= chunk.firstBreak && ci <= chunk.lastBreak)
        assert(chunk.isValidCharacterIndex(ci))

        if ci < chunk.lastBreak {
            // the common case, the full character is in this chunk
            return chunk.string[ci]
        }

        var end = self
        if end.next(using: .characters) == nil {
            end = Rope.Index(endOf: root!)
        }

        var s = ""
        s.reserveCapacity(end.position - position)

        var i = self
        while true {
            let count = min(chunk.count - offset, end.position - i.position)

            let endOffset = offset + count
            assert(endOffset <= chunk.count)

            let cstart = chunk.string.utf8Index(at: offset)
            let cend = chunk.string.utf8Index(at: endOffset)

            s += chunk.string[cstart..<cend]

            if i.position + count == end.position {
                break
            }

            (chunk, offset) = i.nextLeaf()!
        }

        assert(s.count == 1)
        return s[s.startIndex]
    }

    func readLine() -> String? {
        guard var (chunk, offset) = read() else {
            return nil
        }

        var end = self
        if end.next(using: .newlines) == nil {
            end = Rope.Index(endOf: root!)
        }

        var s = ""
        s.reserveCapacity(end.position - position)

        var i = self
        while true {
            let count = min(chunk.count - offset, end.position - i.position)

            let endOffset = offset + count
            assert(endOffset <= chunk.count)

            let cstart = chunk.string.utf8Index(at: offset)
            let cend = chunk.string.utf8Index(at: endOffset)

            s += chunk.string[cstart..<cend]

            if i.position + count == end.position {
                break
            }

            (chunk, offset) = i.nextLeaf()!
        }

        return s
    }
}




// MARK: - Collection conformances


// If I don't specify these conformances separately, I get errors like this:
//
//     Conditional conformance of type 'BTree<Summary>' to protocol 'Collection'
//     does not imply conformance to inherited protocol 'Sequence'
extension Rope: Sequence {
    struct Iterator: IteratorProtocol {
        var index: Index

        mutating func next() -> Character? {
            guard let c = index.readChar() else {
                return nil
            }

            index.next(using: .characters)
            return c
        }
    }

    func makeIterator() -> Iterator {
        Iterator(index: Index(startOf: root))
    }
}

// TODO: audit default methods from Collection, BidirectionalCollection and RangeReplaceableCollection for default implementations that perform poorly.
extension Rope: Collection {
    var count: Int {
        root.measure(using: .characters)
    }

    subscript(position: Index) -> Character {
        position.validate(for: root)
        return index(roundingDown: position, using: .characters).readChar()!
    }

    subscript(bounds: Range<Index>) -> Rope {
        bounds.lowerBound.validate(for: root)
        bounds.upperBound.validate(for: root)

        let start = index(roundingDown: bounds.lowerBound, using: .characters)
        let end = index(roundingDown: bounds.upperBound, using: .characters)

        var sliced = Rope(self, slicedBy: Range(start..<end))

        var old = GraphemeBreaker(for: self, upTo: start)
        var new = GraphemeBreaker()
        sliced.resyncBreaks(old: &old, new: &new)

        return sliced
    }

    func index(after i: Index) -> Index {
        i.validate(for: root)
        return index(after: i, using: .characters)
    }

    func index(_ i: Index, offsetBy distance: Int) -> Index {
        i.validate(for: root)
        return index(i, offsetBy: distance, using: .characters)
    }

    func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        i.validate(for: root)
        limit.validate(for: root)
        return index(i, offsetBy: distance, limitedBy: limit, using: .characters)
    }
}

extension Rope: BidirectionalCollection {
    func index(before i: Index) -> Index {
        i.validate(for: root)
        return index(before: i, using: .characters)
    }
}

extension Rope: RangeReplaceableCollection {
    mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C: Collection, C.Element == Element {
        subrange.lowerBound.validate(for: root)
        subrange.upperBound.validate(for: root)

        let rangeStart = index(roundingDown: subrange.lowerBound, using: .characters)
        let rangeEnd = index(roundingDown: subrange.upperBound, using: .characters)

        var old = GraphemeBreaker(for: self, upTo: rangeEnd, withKnownNextScalar: rangeEnd.position == root.count ? nil : unicodeScalars[rangeEnd])
        var new = GraphemeBreaker(for: self, upTo: rangeStart, withKnownNextScalar: newElements.first?.unicodeScalars.first)

        var b = Builder()
        b.push(&root, slicedBy: Range(startIndex..<rangeStart))
        b.push(string: newElements, breaker: &new)

        var rest = Rope(self, slicedBy: Range(rangeEnd..<endIndex))
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

// A few niceties that make Rope more like String.
extension Rope {
    mutating func append(_ string: String) {
        append(contentsOf: string)
    }

    func index(roundingDown i: Index) -> Index {
        i.validate(for: root)
        return index(roundingDown: i, using: .characters)
    }
}

// Some convenience methods that make string indexing not
// a total pain to work with.
extension Rope {
    func index(at offset: Int) -> Index {
        index(at: offset, using: .characters)
    }

    subscript(offset: Int) -> Character {
        self[index(at: offset, using: .characters)]
    }
}


// MARK: - Grapheme breaking


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

extension Chunk {
    // Returns true if we're in sync, false if we need to sync the next Chunk.
    mutating func resyncBreaks(old: inout Rope.GraphemeBreaker, new: inout Rope.GraphemeBreaker) -> Bool {
        var i = string.startIndex
        var first: String.Index?
        var last: String.Index?

        while i < string.unicodeScalars.endIndex {
            let scalar = string.unicodeScalars[i]
            let a = old.hasBreak(before: scalar)
            let b = new.hasBreak(before: scalar)

            if b {
                first = first ?? i
                last = i
            }

            if a && b {
                // Found the same break. We're done
                break
            } else if !a && !b && old == new {
                // GraphemeBreakers are in the same state. We're done.
                break
            }

            string.unicodeScalars.formIndex(after: &i)
        }

        guard let first, let last else {
            // the chunk has no break, we need to continue to the next chunk.
            prefixCount = string.utf8.count
            suffixCount = string.utf8.count
            return true
        }

        prefixCount = string.utf8.distance(from: string.startIndex, to: first)
        suffixCount = string.utf8.distance(from: string.unicodeScalars.index(after: last), to: string.endIndex)

        // we're done if we stopped iterating before processing the whole chunk
        return i < string.endIndex
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



// MARK: - Views

// There's no UTF16View, but this seems like as good a place as any.
extension Rope {
    var utf16Count: Int {
        root.measure(using: .utf16)
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

// MARK: - Standard library integration

extension String {
    init(_ rope: Rope) {
        self.init()
        self.reserveCapacity(rope.utf8.count)
        for chunk in rope.leaves {
            append(chunk.string)
        }
    }
}

extension NSString {
    convenience init(_ rope: Rope) {
        self.init(string: String(rope))
    }
}


// MARK: - Helpers


fileprivate func countNewlines(in buf: Slice<UnsafeBufferPointer<UInt8>>) -> Int {
    let nl = UInt8(ascii: "\n")
    var count = 0

    for b in buf {
        if b == nl {
            count += 1
        }
    }

    return count
}

fileprivate extension StringProtocol {
    func index(at offset: Int) -> Index {
        index(startIndex, offsetBy: offset)
    }

    func utf8Index(at offset: Int) -> Index {
        utf8.index(startIndex, offsetBy: offset)
    }

    func utf16Index(at offset: Int) -> Index {
        utf16.index(startIndex, offsetBy: offset)
    }

    func unicodeScalarIndex(at offset: Int) -> Index {
        unicodeScalars.index(startIndex, offsetBy: offset)
    }

    // Like withUTF8, but rather than mutating, it just panics if we don't
    // have contiguous UTF-8 storage.
    func withExistingUTF8<R>(_ body: (UnsafeBufferPointer<UInt8>) -> R) -> R {
        utf8.withContiguousStorageIfAvailable { buf in
            body(buf)
        }!
    }
}

