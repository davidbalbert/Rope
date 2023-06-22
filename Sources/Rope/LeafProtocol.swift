//
//  LeafProtocol.swift
//
//
//  Created by David Albert on 6/22/23.
//

import Foundation

protocol LeafProtocol {
    associatedtype Index: Comparable
    associatedtype Element

    // The length of the leaf in base units
    var count: Int { get }
    var atLeastMinSize: Bool { get }

    init()
    mutating func push(possiblySplitting other: Self) -> Self?

    func index(before i: Index) -> Index
    func index(after i: Index) -> Index
    func index(_ index: Index, offsetBy distance: Int) -> Index
    var startIndex: Index { get }
    var endIndex: Index { get }

    subscript(index: Index) -> Element { get }
    subscript(range: Range<Index>) -> Self { get }
}
