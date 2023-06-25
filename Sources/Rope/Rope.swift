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

    static func summarize(_ chunk: Chunk) -> RopeSummary {
        RopeSummary(
            utf16: chunk.countUTF16(),
            chars: chunk.countChars(),
            lines: chunk.countLines()
        )
    }
}

typealias Rope = BTree<RopeSummary>

extension Rope {
    mutating func append(_ string: String) {
        append(contentsOf: string)
    }
}
