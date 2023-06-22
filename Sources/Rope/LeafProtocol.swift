//
//  LeafProtocol.swift
//
//
//  Created by David Albert on 6/22/23.
//

import Foundation

protocol LeafProtocol: BidirectionalCollection where SubSequence == Self {
    // Already in BidirectionCollection, but important enough to point
    // out here. Must be in base units.
    var count: Int { get }

    // Initializes an empty leaf.
    init()
    var isUndersized: Bool { get }
    mutating func push(possiblySplitting other: Self) -> Self?
}
