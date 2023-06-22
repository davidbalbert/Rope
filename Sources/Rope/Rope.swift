//
//  Rope.swift
//
//
//  Created by David Albert on 6/21/23.
//

import Foundation

struct RopeSummary: SummaryProtocol {
    var utf16: Int
    var chars: Int
    var lines: Int

    static func += (left: inout RopeSummary, right: RopeSummary) {
        left.utf16 += right.utf16
        left.chars += right.chars
        left.lines += right.lines
    }

    static var zero: RopeSummary {
        RopeSummary(utf16: 0, chars: 0, lines: 0)
    }

    func summarize(_ chunk: Chunk) -> RopeSummary {
        RopeSummary(
            utf16: chunk.countUTF16(),
            chars: chunk.countChars(),
            lines: chunk.countLines()
        )
    }
}

typealias Rope = Tree<RopeSummary>

extension Rope {
    public init(_ string: String) {
        var b = Builder()
        b.push(string: string)
        self.init(b.build())
    }

    public init<S>(_ string: S) where S: Collection, S.Element == Character {
        var b = Builder()
        b.push(string: String(string))
        self.init(b.build())
    }

    mutating func append(_ string: String) {
        append(contentsOf: string)
    }
}

extension Rope: RangeReplaceableCollection where Element == Character {
    mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C: Collection, C.Element == Character {
        subrange.lowerBound.validate(for: root)
        subrange.upperBound.validate(for: root)

        var b = Builder()
        b.push(&root, slicedBy: Range(startIndex..<subrange.lowerBound))
        b.push(string: String(newElements))
        b.push(&root, slicedBy: Range(subrange.upperBound..<endIndex))
        self.root = b.build()
    }

    // The deafult implementation calls append(_:) in a loop. This should be faster.
    mutating func append<S>(contentsOf newElements: S) where S : Sequence, S.Element == Character {
        var b = Builder()
        b.push(&root)
        b.push(string: String(newElements))
        self.root = b.build()
    }

    // override the default behavior
    mutating func reserveCapacity(_ n: Int) {
        // no-op
    }
}
