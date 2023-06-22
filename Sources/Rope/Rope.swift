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
    mutating func append(_ string: String) {
        append(contentsOf: string)
    }
}
