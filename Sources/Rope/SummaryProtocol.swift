//
//  SummaryProtocol.swift
//
//
//  Created by David Albert on 6/22/23.
//

import Foundation

protocol SummaryProtocol {
    associatedtype Leaf: LeafProtocol

    // A subset of AdditiveArithmetic
    static func += (lhs: inout Self, rhs: Self)
    static var zero: Self { get }

    func summarize(_ leaf: Leaf) -> Self
}
