//
//  BTreeMetric.swift
//
//
//  Created by David Albert on 6/28/23.
//

import Foundation

protocol BTreeMetric<Summary> {
    associatedtype Summary: BTreeSummary

    func measure(summary: Summary, count: Int) -> Int
    func convertToBaseUnits(_ measuredUnits: Int, in leaf: Summary.Leaf) -> Int
    // TODO: Maybe rename to convertFromBaseUnits?
    func convertToMeasuredUnits(_ baseUnits: Int, in leaf: Summary.Leaf) -> Int
    func isBoundary(_ offset: Int, in leaf: Summary.Leaf) -> Bool

    // In prev(_:in:), offset may be one beyond the end of the leaf
    // (i.e. offset == leaf.count).
    func prev(_ offset: Int, in leaf: Summary.Leaf) -> Int?
    func next(_ offset: Int, in leaf: Summary.Leaf) -> Int?

    var canFragment: Bool { get }
}
