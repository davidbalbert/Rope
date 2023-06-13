//
//  Range+Extensions.swift
//  
//
//  Created by David Albert on 6/13/23.
//

import Foundation

extension Range<Int> {
    init(_ ropeRange: Range<Rope.Index>) {
        self.init(uncheckedBounds: (ropeRange.lowerBound.nodeIndex.position, ropeRange.upperBound.nodeIndex.position))
    }
}

extension Range where Bound: Strideable, Bound.Stride: SignedInteger {
    func offset(by offset: Bound.Stride) -> Self {
        lowerBound.advanced(by: offset)..<upperBound.advanced(by: offset)
    }
}
