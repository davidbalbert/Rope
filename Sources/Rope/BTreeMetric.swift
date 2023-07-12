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

    func measure(summary: Summary, count: Int) -> Int
    func convertToBaseUnits(_ measuredUnits: Int, in leaf: Summary.Leaf) -> Int
    func convertFromBaseUnits(_ baseUnits: Int, in leaf: Summary.Leaf) -> Int
    func isBoundary(_ offset: Int, in leaf: Summary.Leaf) -> Bool

    // Never called with offset == 0
    func prev(_ offset: Int, in leaf: Summary.Leaf) -> (Int, Int?)?
    func next(_ offset: Int, in leaf: Summary.Leaf) -> (Int, Int?)?

    var canFragment: Bool { get }
    var type: BTree<Summary>.MetricType { get }
}
