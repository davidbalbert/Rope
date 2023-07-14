//
//  Range+Extensions.swift
//  
//
//  Created by David Albert on 6/13/23.
//

import Foundation

extension Range<Int> {
    init<Summary>(_ treeRange: Range<BTree<Summary>.Index>) {
        self.init(uncheckedBounds: (treeRange.lowerBound.position, treeRange.upperBound.position))
    }
}

extension Range where Bound: Strideable, Bound.Stride: SignedInteger {
    func offset(by offset: Bound.Stride) -> Self {
        lowerBound.advanced(by: offset)..<upperBound.advanced(by: offset)
    }
}
