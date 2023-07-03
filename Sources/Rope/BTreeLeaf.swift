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

    // Specified in base units. Should be O(1).
    subscript(bounds: Range<Int>) -> Self { get }
}
