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
        // TODO: this is SPI. Hopefully it gets exposed soon.
        return s.unicodeScalars._index(roundingDown: i)
    }

    var string: String
    var prefixCount: Int
    var suffixCount: Int

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
        self.init("", prefixCount: 0, suffixCount: 0)
    }

    init(_ elements: some Sequence<Character>, prefixCount: Int, suffixCount: Int) {
        var s = String(elements)
        s.makeContiguousUTF8()
        assert(s.utf8.count <= Chunk.maxSize)
        self.string = s
        self.prefixCount = prefixCount
        self.suffixCount = suffixCount
    }

    mutating func push(possiblySplitting other: Chunk) -> Chunk? {
        let nprev = string.utf8.count
        string += other.string

        if string.utf8.count <= Chunk.maxSize {
            // TODO: prefix count should stay the same. Start from there and update suffixCount.

            return nil
        } else {
            let i = Chunk.boundaryForMerge(string[...])

            let n = string.utf8.distance(from: string.startIndex, to: i)

            // the problem here is that if prefixCount == suffixCount == nprev,
            // we need to search back to a potentially arbitrary prior chunk
            // in order to build up our GraphemeBreaker

            // TODO!
            let newPrefixCount = min(prefixCount, n)
            let newSuffixCount = min(suffixCount, n)

            // prefix count could in theory end up shorter
            // suffixCount starts correct.

            let rest = String(string.unicodeScalars[i...])
            string = String(string.unicodeScalars[..<i])

            // TODO: prefixCount, suffixCount
            return Chunk(rest, prefixCount: 0, suffixCount: 0)
        }
    }

    // Returns true if we're in sync, false if we need to sync the next Chunk.
    mutating func resyncBreaks(old: inout Rope.GraphemeBreaker, new: inout Rope.GraphemeBreaker) -> Bool {
        // TODO: The next step is to resync breaks in
        false
    }

    // Why do we need fixup(previous:)? Consider these this example:
    //
    // Two chunks, one ending in "e" and the other starting with
    // U+0301 (the combining acute accent). Before adding the second
    // chunk, the states are as follows:
    //
    //    - first.suffixCount == 0 because "e" is a complete grapheme cluster
    //    - second.prefixCount == 0. Even though U+0301 is a combining character
    //      when it's at the beginning of a string, Swift treats it as its own
    //      character.
    //
    // After appending the second chunk onto a rope ending with the first chunk,
    // we want to be in the following state:
    //
    //    - first.suffixCount == 1 because "e" is no longer a complete
    //      grapheme cluster.
    //    - second.prefixCount == 1 because U+0301 now combined with the "e",
    //      so Swift's special behavior of treating it as its own character
    //      because it's at the beginning of the string no longer applies.
    //
    // When does this have to be called?
    // - When we modify a chunk with push(possiblySplitting:). Consider the sequence
    //   [C0, C1, C2] where we call push(possiblySplitting:) on C1.
    //   - If it returns nil, then we have to call C1.fixup(next: &C2). This is because
    //     C2 might start with a combining character... Do we even need to do this?
    //     If C2 was already present and had a combining character
    //
    //   - If it returns a new chunk C2, then we have to call C1.fixup(previous: prev(C1))
    //     and next(C2).fixup(previous: C2). This assumes that C1's suffix and C2's prefix
    //     are already correct.
    // - If we're inserting a new chunk even if we don't call push(possiblySplitting:).
    //   This is the more complicated situation that I don't understand yet.
    //
    //   Specifically, I'd like to not call fixup more than I need to. The different situations
    //   where I might call fixup are Node.concatinate(), Builder.push(_:), Builder.pop(_:). There
    //   are probably more as well. This will take a lot of thinking.
    //     
    // I also have to make sure prefixCount and suffixCount stay on UnicodeScalar boundaries.

    subscript(bounds: Range<Int>) -> Chunk {
        let start = string.utf8Index(at: bounds.lowerBound).samePosition(in: string.unicodeScalars)
        let end = string.utf8Index(at: bounds.upperBound).samePosition(in: string.unicodeScalars)

        guard let start, let end else {
            fatalError("invalid unicode scalar offsets")
        }

        // TODO: add prefixCount and suffixCount
        return Chunk(string[start..<end], prefixCount: 0, suffixCount: 0)
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

    func isValidUTF16Index(_ i: String.Index) -> Bool {
        i.samePosition(in: string.utf16) != nil
    }

    func isValidUnicodeScalarIndex(_ i: String.Index) -> Bool {
        i.samePosition(in: string.unicodeScalars) != nil
    }

    func isValidCharacterIndex(_ i: String.Index) -> Bool {
        i == characters._index(roundingDown: i)
    }
}
