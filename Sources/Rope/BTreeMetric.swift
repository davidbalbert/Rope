//
//  BTreeMetric.swift
//
//
//  Created by David Albert on 6/28/23.
//

import Foundation

extension BTree {
    enum MetricType {
        case leading
        case trailing
    }
}

protocol BTreeMetric<Summary> {
    associatedtype Summary: BTreeSummary

    typealias Leaf = Summary.Leaf
    typealias State = Summary.IndexState

    // count is the count in the base metric
    func measure(summary: Summary, count: Int) -> Int
    func convertToBaseUnits(_ measuredUnits: Int, in leaf: Leaf) -> Int
    func convertFromBaseUnits(_ baseUnits: Int, in leaf: Leaf) -> Int
    func isBoundary(_ offset: Int, in leaf: Leaf) -> Bool

    // prev(_:in:) is never called with offset == 0
    func prev(_ offset: Int, state: State, in leaf: Summary.Leaf) -> (Int, State)?
    func next(_ offset: Int, state: State, in leaf: Summary.Leaf) -> (Int, State)?

    func state(for measuredUnits: Int, in leaf: Leaf) -> State

    var canFragment: Bool { get }
    var type: BTree<Summary>.MetricType { get }
}

extension BTreeMetric {
    func state(for measuredUnits: Int, in leaf: Leaf) -> State {
        .zero
    }
}
