//
//  Chunk.swift
//
//
//  Created by David Albert on 6/22/23.
//

import Foundation

struct Chunk: BTreeElement {
    static func makeLeavesFrom(contentsOf elements: some Sequence<Character>) -> UnfoldSequence<Chunk, String.Index> {
        var s = String(elements)
        s.makeContiguousUTF8()

        return sequence(state: s.startIndex) { i in
            var substring = s[i...]

            if substring.isEmpty {
                return nil
            }

            if s.utf8.count <= Chunk.maxSize {
                i = substring.endIndex
                return Chunk(s)
            } else {
                let n = substring.utf8.count

                if n > Chunk.maxSize {
                    let minSplit = Chunk.minSize
                    let maxSplit = Swift.min(Chunk.maxSize, n - Chunk.minSize)

                    let nl = UInt8(ascii: "\n")
                    let lineBoundary = substring.withUTF8 { buf in
                        buf[minSplit..<maxSplit].firstIndex(of: nl)
                    }

                    let offset = lineBoundary ?? maxSplit
                    let codepoint = substring.utf8.index(substring.startIndex, offsetBy: offset)
                    // TODO: this is SPI. Hopefully it gets exposed soon.
                    i = substring.unicodeScalars._index(roundingDown: codepoint)
                } else {
                    i = substring.endIndex
                }

                return Chunk(substring[..<i])
            }
        }
    }

    // measured in base units
    static let minSize = 511
    static let maxSize = 1023

    var string: String

    init() {
        self.string = ""
    }

    init<S>(_ s: S) where S: Sequence, S.Element == Character {
        var s = String(s)
        s.makeContiguousUTF8()
        assert(s.utf8.count <= Chunk.maxSize)
        self.string = s
    }

    var count: Int {
        string.utf8.count
    }

    var isUndersized: Bool {
        count < Chunk.minSize
    }

    func countChars() -> Int {
        string.count
    }

    func countUTF16() -> Int {
        string.utf16.count
    }

    func countLines() -> Int {
        assert(string.isContiguousUTF8)

        let nl = UInt8(ascii: "\n")
        var count = 0

        // countLines isn't mutating, so we can't use withUTF8.
        // That said, we're guaranteed to have a contiguous utf8
        // string, so this should always succeed.
        string.utf8.withContiguousStorageIfAvailable { buf in
            for c in buf {
                if c == nl {
                    count += 1
                }
            }
        }

        return count
    }

    mutating func push(possiblySplitting other: Chunk) -> Chunk? {
        string += other.string
        let n = string.utf8.count

        if n <= Chunk.maxSize {
            return nil
        } else {
            // for the smallest chunk that needs splitting (n = maxSize + 1 = 1024):
            // minSplit = max(511, 1024 - 1023) = max(511, 1) = 511
            // maxSplit = min(1023, 1024 - 511) = min(1023, 513) = 513

            let minSplit = Swift.max(Chunk.minSize, n - Chunk.maxSize)
            let maxSplit = Swift.min(Chunk.maxSize, n - Chunk.minSize)

            let nl = UInt8(ascii: "\n")
            let lineBoundary = string.withUTF8 { buf in
                buf[minSplit..<maxSplit].firstIndex(of: nl)
            }

            let offset = lineBoundary ?? maxSplit
            let idx = string.utf8.index(string.startIndex, offsetBy: offset)
            // TODO: this is SPI. Hopefully it gets exposed soon.
            let adjusted = string.unicodeScalars._index(roundingDown: idx)

            let rest = String(string.unicodeScalars[adjusted...])
            string = String(string.unicodeScalars[..<adjusted])

            return Chunk(rest)
        }
    }

    var startIndex: String.Index {
        string.startIndex
    }

    var endIndex: String.Index {
        string.endIndex
    }

    func index(before i: String.Index) -> String.Index {
        string.index(before: i)
    }

    func index(after i: String.Index) -> String.Index {
        string.index(after: i)
    }

    subscript(index: String.Index) -> Character {
        string[index]
    }

    subscript(range: Range<String.Index>) -> Chunk {
        Chunk(string[range])
    }
}
