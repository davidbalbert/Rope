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
    static func summarize(_ leaf: Leaf) -> Self
}
