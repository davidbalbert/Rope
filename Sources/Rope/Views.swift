//
//  Views.swift
//  Rope
//
//  Created by David Albert on 6/30/23.
//

import Foundation

// N.b. These will be accessable as BTree.*View, BTree<RopeSummary>.*View,
// and Rope.*View, but not BTree<SomeOtherSummary>.*View.
extension Rope {
    var utf8: UTF8View {
        UTF8View(base: self)
    }

    struct UTF8View {
        var base: Rope

        var count: Int {
            base.count
        }
    }
}

extension Rope {
    var utf16: UTF16View {
        UTF16View(base: self)
    }

    struct UTF16View {
        var base: Rope

        var count: Int {
            base.root.summary.utf16
        }
    }
}

extension Rope {
    var unicodeScalars: UnicodeScalarView {
        UnicodeScalarView(base: self)
    }

    struct UnicodeScalarView {
        var base: Rope

        var count: Int {
            base.root.summary.scalars
        }
    }
}

extension Rope {
    var lines: LinesView {
        LinesView(base: self)
    }

    struct LinesView {
        var base: Rope

        var count: Int {
            // TODO: test and verify that `+ 1` is correct.
            base.root.summary.newlines + 1
        }
    }
}

extension Rope {
    var chunks: ChunksView {
        ChunksView(base: self)
    }

    struct ChunksView {
        var base: Rope
    }
}

extension Rope.ChunksView: Sequence {
    struct Iterator: IteratorProtocol {
        var index: Rope.Index

        mutating func next() -> Chunk? {
            guard let (chunk, _) = index.read() else {
                return nil
            }

            index.nextLeaf()
            return chunk
        }
    }

    func makeIterator() -> Iterator {
        Iterator(index: Rope.Index(startOf: base.root))
    }
}
