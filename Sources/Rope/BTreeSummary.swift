//
//  BtreeSummary.swift
//
//
//  Created by David Albert on 6/22/23.
//

import Foundation

protocol BTreeSummary {
    associatedtype Leaf: BTreeLeaf

    // A subset of AdditiveArithmetic
    static func += (lhs: inout Self, rhs: Self)
    static var zero: Self { get }
    
    init(summarizing leaf: Leaf)
}

protocol BTreeDefaultMetric: BTreeSummary {
    associatedtype DefaultMetric: BTreeMetric<Self>

    static var defaultMetric: DefaultMetric { get }
}
