//
//  Chunk.swift
//
//
//  Created by David Albert on 6/22/23.
//

import Foundation

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
        (self.prefixCount, self.suffixCount) = Chunk.calculateBreaks(in: s, using: &b)
    }

    mutating func pushMaybeSplitting(other: Chunk) -> Chunk? {
        string += other.string
        var b = breaker

        if string.utf8.count <= Chunk.maxSize {
            (prefixCount, suffixCount) = Chunk.calculateBreaks(in: string, using: &b)
            return nil
        } else {
            let i = Chunk.boundaryForMerge(string[...])

            let rest = String(string.unicodeScalars[i...])
            string = String(string.unicodeScalars[..<i])

            (prefixCount, suffixCount) = Chunk.calculateBreaks(in: string, using: &b)
            return Chunk(rest[...], breaker: &b)
        }
    }

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

    func countChars() -> Int {
        characters.count
    }

    func countUTF16() -> Int {
        string.utf16.count
    }

    func countScalars() -> Int {
        string.unicodeScalars.count
    }

    func countNewlines() -> Int {
        var count = 0
        string.withExistingUTF8 { buf in
            count = Chunk.countNewlines(in: buf[...])
        }

        return count
    }

    func isValidUnicodeScalarIndex(_ i: String.Index) -> Bool {
        i.samePosition(in: string.unicodeScalars) != nil
    }

    func isValidCharacterIndex(_ i: String.Index) -> Bool {
        i == characters._index(roundingDown: i)
    }
}

// helpers
extension Chunk {
    static func countNewlines(in buf: Slice<UnsafeBufferPointer<UInt8>>) -> Int {
        let nl = UInt8(ascii: "\n")
        var count = 0

        for b in buf {
            if b == nl {
                count += 1
            }
        }

        return count
    }

    static func boundaryForBulkInsert(_ s: Substring) -> String.Index {
        chunkBoundary(for: s, startingAt: Chunk.minSize)
    }

    static func boundaryForMerge(_ s: Substring) -> String.Index {
        // for the smallest chunk that needs splitting (n = maxSize + 1 = 1024):
        // minSplit = max(511, 1024 - 1023) = max(511, 1) = 511
        // maxSplit = min(1023, 1024 - 511) = min(1023, 513) = 513
        chunkBoundary(for: s, startingAt: max(Chunk.minSize, s.utf8.count - Chunk.maxSize))
    }

    static func chunkBoundary(for s: Substring, startingAt minSplit: Int) -> String.Index {
        let maxSplit = min(Chunk.maxSize, s.utf8.count - Chunk.minSize)

        let nl = UInt8(ascii: "\n")
        let lineBoundary = s.withExistingUTF8 { buf in
            buf[(minSplit-1)..<maxSplit].lastIndex(of: nl)
        }

        let offset = lineBoundary ?? maxSplit
        let i = s.utf8Index(at: offset)
        return s.unicodeScalars._index(roundingDown: i)
    }

    static func calculateBreaks(in string: String, using breaker: inout Rope.GraphemeBreaker) -> (prefixCount: Int, suffixCount: Int) {
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
}
