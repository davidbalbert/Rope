//
//  LeafProtocol.swift
//
//
//  Created by David Albert on 6/22/23.
//

import Foundation

protocol LeafProtocol: BidirectionalCollection where SubSequence == Self {
    associatedtype Leaves: Sequence<Self>
    static func makeLeavesFrom(contentsOf elements: some Sequence<Element>) -> Leaves

    // Already in BidirectionCollection, but important enough to point
    // out here. Must be in base units.
    var count: Int { get }

    // From RangeReplacableCollection
    init()
    init<S>(_ elements: S) where S : Sequence, Self.Element == S.Element
    
    var isUndersized: Bool { get }
    mutating func push(possiblySplitting other: Self) -> Self?
}
