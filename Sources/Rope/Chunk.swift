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

//    static func from(contentsOf elements: some Sequence<Character>) -> UnfoldSequence<Chunk, String.Index> {
//        var s = String(elements)
//        s.makeContiguousUTF8()
//
//        return sequence(state: s.startIndex) { i in
//            var substring = s[i...]
//
//            if substring.isEmpty {
//                return nil
//            }
//
//            if substring.utf8.count <= Chunk.maxSize {
//                i = substring.endIndex
//                return Chunk(substring)
//            } else {
//                let n = substring.utf8.count
//
//                if n > Chunk.maxSize {
//                    let minSplit = Chunk.minSize
//                    let maxSplit = Swift.min(Chunk.maxSize, n - Chunk.minSize)
//
//                    let nl = UInt8(ascii: "\n")
//                    let lineBoundary = substring.withUTF8 { buf in
//                        buf[(minSplit-1)..<maxSplit].lastIndex(of: nl)
//                    }
//
//                    let offset = lineBoundary ?? maxSplit
//                    let codepoint = substring.utf8.index(substring.startIndex, offsetBy: offset)
//                    // TODO: this is SPI. Hopefully it gets exposed soon.
//                    i = substring.unicodeScalars._index(roundingDown: codepoint)
//                } else {
//                    i = substring.endIndex
//                }
//
//                return Chunk(substring[..<i])
//            }
//        }
//    }

    var string: String

    init() {
        self.init("")
    }

    init(_ elements: some Sequence<Character>) {
        var s = String(elements)
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
                buf[(minSplit-1)..<maxSplit].lastIndex(of: nl)
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

    // This seems wrong. Can we get rid of it?
    subscript(offset: Int) -> Character {
        guard let i = string.utf8Index(at: offset).samePosition(in: string) else {
            fatalError("invalid character offset")
        }

        return string[i]
    }

    subscript(bounds: Range<Int>) -> Chunk {
        let start = string.utf8Index(at: bounds.lowerBound).samePosition(in: string.unicodeScalars)
        let end = string.utf8Index(at: bounds.upperBound).samePosition(in: string.unicodeScalars)

        guard let start, let end else {
            fatalError("invalid unicode scalar offsets")
        }

        return Chunk(string[start..<end])
    }

    func countChars() -> Int {
        string.count
    }

    func countUTF16() -> Int {
        string.utf16.count
    }

    func countScalars() -> Int {
        string.unicodeScalars.count
    }

    func countNewlines() -> Int {
        assert(string.isContiguousUTF8)

        let nl = UInt8(ascii: "\n")
        var count = 0

        // countNewlines isn't mutating, so we can't use withUTF8.
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
}
