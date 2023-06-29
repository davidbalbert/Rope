//
//  BTreeLeaf.swift
//
//
//  Created by David Albert on 6/22/23.
//

import Foundation

protocol BTreeLeaf {
    init()

    // Measured in base units
    var count: Int { get }
    var isUndersized: Bool { get }
    mutating func push(possiblySplitting other: Self) -> Self?

    // Called while building a tree when adding a new leaf.
    // Sometimes, the state of a leaf's previous sibling
    // can change the state of the new leaf, and sometimes
    // the new leaf can change the state of the previous sibling.
    // See the comments above Chunk.fixup(previous:) for an
    // example of when this might happen.
    mutating func fixup(previous: inout Self?)

    // Specified in base units. Should be O(1).
    subscript(bounds: Range<Int>) -> Self { get }
}
