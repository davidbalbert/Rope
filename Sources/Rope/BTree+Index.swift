//
//  BTree+Index.swift
//
//
//  Created by David Albert on 6/13/23.
//

import Foundation

extension BTree {
    struct PathElement {
        // An index is valid only if it's root present and it's mutation
        // count is equal to the root's mutation count. If both of those
        // are true, we're guaranteed that the path is valid, so we can
        // unowned instead of weak references for the nodes.
        unowned var node: Node
        var slot: Int // child index
        
        var child: Node {
            node.children[slot]
        }
    }
    
    struct Index {
        weak var root: Node?
        let mutationCount: Int
        
        var position: Int
        
        var path: [PathElement]
        
        var leaf: Leaf? // Present unless the index is invalid.
        var offsetOfLeaf: Int // Position of the first element of the leaf in base units. -1 if we're invalid.
        
        // Must be less than leaf.count unless we're at the end of the rope, in which case
        // it's equal to leaf.count.
        var offsetInLeaf: Int {
            position - offsetOfLeaf
        }

        // Sometimes, a location in a tree cannot be precisely represented by position alone.
        // Specifically, given that the Rope's storage is UTF-8 encoded, it's impossible
        // for position to point at a UTF-16 trailing surrogate – it doesn't exist in the
        // encoded data.
        //
        // This only matters if we can't round-trip a measured offset. Specifically, if
        // count(metric, offset(metric, measured)) != measured, then we know that position alone
        // can't represent our location, and we need to keep track of measured position as well.
        // These measured* properties will only be set if the above holds true.
        //
        // While measuredOffsetOfLeaf gets set when measuredPosition gets set, clearing
        // measuredPosition doesn't clear measuredOffsetOfLeaf unless we're changing leaves. In
        // other words, we cache measuredOffsetOfLeaf once set, as long as we continue to
        // stay on the same leaf. Consider the situtation where we're iterating over UTF-16 code
        // units, where each scalar is outside of the BMP and is represented by a surrogate pair.
        // Every time we call next() on the iterator, we'll toggle measuredPosition between nil
        // depending on whether we're on a leading or trailing surrogate. If we didn't cache
        // measuredOffsetOfLeaf, we'd have to calculate it from the root on every other call
        // to next().
        //
        // Ways to set measured* properties if necessary:
        // - Index(at:measuredBy:in:)
        // - Index.next(using:)
        // - Index.prev(using:)
        //
        // It is an error to have count(metric, offset(metric, measured)) != measured if
        // metric.canFragment is true. This is because we assume that the start and end of
        // leaves can always be referenced by position.
        //
        // Methods that unset both measured* properties:
        // - Index.nextLeaf()
        // - Index.prevLeaf()
        // - Index.set()
        //
        // Methods that unset measuredPosition, leaving measuredOffsetOfLeaf:
        // - Index.floorLeaf()
        var measuredPosition: (Int, any BTreeMetric<Summary>)?

        // We keep measuredOffsetOfLeaf around even when measuredPosition
        // is nil, because a common operation is iterating through measured
        // positions
        var measuredOffsetOfLeaf: (Int, any BTreeMetric<Summary>)?

        var measuredOffsetInLeaf: Int? {
            guard let (mpos, m1) = measuredPosition, let (mleaf, m2) = measuredOffsetOfLeaf else {
                return nil
            }
            assert(type(of: m1) == type(of: m2))
            return mpos - mleaf
        }
        
        init(at offset: Int, in root: Node) {
            precondition((0...root.count).contains(offset), "Index out of bounds")
            
            self.root = root
            self.mutationCount = root.mutationCount
            self.position = offset
            self.path = []
            self.leaf = nil
            self.offsetOfLeaf = -1
            
            descend()
        }
    }
}

extension BTree.Index where Summary: BTreeDefaultMetric {
    init<M>(at measuredOffset: Int, measuredBy metric: M, in root: BTree.Node) where M: BTreeMetric<Summary> {
        let total = root.measure(using: metric)
        precondition((0...total).contains(measuredOffset), "Index out of bounds")

        let offset = root.offset(of: measuredOffset, measuredIn: metric)
        assert((0...root.count).contains(offset))

        self.root = root
        self.mutationCount = root.mutationCount
        self.position = offset
        self.path = []
        self.leaf = nil
        self.offsetOfLeaf = -1

        if root.count(metric, upThrough: self.position) != measuredOffset {
            precondition(!metric.canFragment)
            self.measuredPosition = (measuredOffset, metric)
        }

        descend()
    }

    mutating func offset<M>(by distance: Int, using metric: M) where M: BTreeMetric<Summary> {
        assert(root != nil)

        let m = root!.count(metric, upThrough: position)
        let newM = m + distance

        precondition(newM >= 0 && newM <= root!.measure(using: metric), "Index out of bounds")

        self.position = root!.offset(of: newM, measuredIn: metric)

        let needsMeasured = root!.count(metric, upThrough: self.position) != newM

        if needsMeasured {
            precondition(!metric.canFragment)
            measuredPosition = (newM, metric)
        }

        if let leaf {
            let leafEnd = offsetOfLeaf + leaf.count

            if position >= offsetOfLeaf && (position < leafEnd || root!.count == position && position == leafEnd) {
                if needsMeasured && (measuredOffsetOfLeaf == nil || type(of: measuredOffsetOfLeaf!.1) != type(of: metric)) {
                    measuredOffsetOfLeaf = (measure(upToLeafContaining: offsetOfLeaf, using: metric), metric)
                }

                // We're still in the same leaf. No need to descend.
                return
            }
        }

        descend()
    }
}

extension BTree.Index {
    mutating func descend() {
        path = []
        var node = root! // assume we have a root
        var offset = 0
        var measuredOffset = 0
        while !node.isLeaf {
            var slot = 0
            for child in node.children.dropLast() {
                if position < offset + child.count {
                    break
                }
                offset += child.count
                slot += 1

                if let (_, metric) = measuredPosition {
                    measuredOffset += child.measure(using: metric)
                }
            }
            path.append(BTree.PathElement(node: node, slot: slot))
            node = node.children[slot]
        }

        self.leaf = node.leaf
        self.offsetOfLeaf = offset

        if let (_, metric) = measuredPosition {
            self.measuredOffsetOfLeaf = (measuredOffset, metric)
        }
    }

    init(startOf root: BTree.Node) {
        self.init(at: 0, in: root)
    }

    init(endOf root: BTree.Node) {
        self.init(at: root.count, in: root)
    }

    var isAtEnd: Bool {
        leaf != nil && root?.count == position
    }

    func isBoundary<M>(in metric: M) -> Bool where M: BTreeMetric<Summary> {
        assert(root != nil)

        guard let leaf else {
            return false
        }

        if offsetInLeaf == 0 && !metric.canFragment {
            return true
        }

        // If we have a measured position in this metric, we're on a boundary
        // by definition.
        if let (_, m) = measuredPosition, type(of: m) == type(of: metric) {
            return true
        }

        switch metric.type {
        case .leading:
            if position == root!.count {
                return true
            } else if offsetInLeaf == leaf.count {
                // We have to look at the next leaf to see if we have a boundary.
                // This is not tested, and I don't know if it works.
                let (next, _) = peekNextLeaf()!
                return metric.isBoundary(0, in: next)
            } else {
                return metric.isBoundary(offsetInLeaf, in: leaf)
            }
        case .trailing:
            if position == 0 {
                return true
            } else if offsetInLeaf == 0 {
                // We have to look to the previous leaf to
                // see if we have a boundary.
                let (prev, _) = peekPrevLeaf()!
                return metric.isBoundary(prev.count, in: prev)
            } else {
                return metric.isBoundary(offsetInLeaf, in: leaf)
            }
        }
    }

    @discardableResult
    mutating func prev<M>(using metric: M) -> Int? where M: BTreeMetric<Summary> {
        assert(root != nil)

        if position == 0 || leaf == nil {
            invalidate()
            return nil
        }

        // try to find a boundary within this leaf
        if let offset = prev(withinLeafUsing: metric) {
            return offset
        }

        // If we didn't find a boundary, go to the previous leaf and
        // try again.
        guard let (leaf, _) = prevLeaf() else {
            // we were on the first leaf, so we're done.
            return nil
        }

        // one more shot
        position = offsetOfLeaf + leaf.count
        if let offset = prev(withinLeafUsing: metric) {
            return offset
        }

        // We've searched at least one full leaf backwards and
        // found nothing. Just start at the top and descend instead.
        //
        // TODO: it's possible this only works with trailing boundaries, but
        // I'm not sure.
        let measure = measure(upToLeafContaining: offsetOfLeaf, using: metric)
        descend(toLeafContaining: measure, asMeasuredBy: metric)

        position = offsetOfLeaf + leaf.count
        if let offset = prev(withinLeafUsing: metric) {
            return offset
        }

        // we didn't find anything
        invalidate()
        return nil
    }

    @discardableResult
    mutating func next<M>(using metric: M) -> Int? where M: BTreeMetric<Summary> {
        assert(root != nil)

        if position == root!.count || leaf == nil {
            invalidate()
            return nil
        }

        if let offset = next(withinLeafUsing: metric) {
            return offset
        }

        // There was no boundary in the leaf we started on. Move to the next one.
        if nextLeaf() == nil {
            // the leaf we started on was the last leaf, and we didn't
            // find a boundary, so now we're at the end.
            return nil
        }

        // one more shot
        if let offset = next(withinLeafUsing: metric) {
            return offset
        }

        // We've searched at least one full leaf forwards and
        // found nothing. Just start at the top and descend instead.
        //
        // TODO: it's possible this only works with trailing boundaries, but
        // I'm not sure.
        let measure = measure(upToLeafContaining: offsetOfLeaf, using: metric)
        descend(toLeafContaining: measure+1, asMeasuredBy: metric)

        if let offset = next(withinLeafUsing: metric) {
            return offset
        }

        // we didn't find anything
        invalidate()
        return nil
    }

    mutating func prev<M>(withinLeafUsing metric: M) -> Int? where M: BTreeMetric<Summary> {
        assert(root != nil && leaf != nil)

        if offsetInLeaf == 0 {
            return nil
        }

        let newOffsets = metric.prev(offsetInLeaf, in: leaf!)

        if newOffsets == nil && offsetOfLeaf == 0 && metric.type == .trailing {
            // Didn't find a boundary, but trailing metrics have
            // a boundary at startIndex.
            measuredPosition = nil
            position = 0
            return position
        }

        guard let (newOffsetInLeaf, newMeasuredOffsetInLeaf) = newOffsets else {
            return nil
        }

        if let newMeasuredOffsetInLeaf {
            if let (mleaf, m) = measuredOffsetOfLeaf, type(of: m) == type(of: metric) {
                measuredPosition = (mleaf + newMeasuredOffsetInLeaf, metric)
            } else {
                let mleaf = measure(upToLeafContaining: offsetOfLeaf, using: metric)
                measuredOffsetOfLeaf = (mleaf, metric)
                measuredPosition = (mleaf + newMeasuredOffsetInLeaf, metric)
            }
            position = offsetOfLeaf + newOffsetInLeaf
        } else {
            measuredPosition = nil
            position = offsetOfLeaf + newOffsetInLeaf
        }

        return position
    }

    mutating func next<M>(withinLeafUsing metric: M) -> Int? where M: BTreeMetric<Summary> {
        assert(root != nil && leaf != nil)

        let isLastLeaf = offsetOfLeaf + leaf!.count == root!.count

        let newOffsets = metric.next(offsetInLeaf, in: leaf!)

        if newOffsets == nil && isLastLeaf && metric.type == .leading {
            // Didn't find a boundary, but leading metrics have a
            // boundary at endIndex.
            measuredPosition = nil
            position = offsetOfLeaf + leaf!.count
            return position
        }

        guard let (newOffsetInLeaf, newMeasuredOffsetInLeaf) = newOffsets else {
            return nil
        }

        if newOffsetInLeaf == leaf!.count && !isLastLeaf {
            assert(newMeasuredOffsetInLeaf == nil)
            // sets position = offsetOfLeaf + leaf!.count, and unsets measured* properties.
            nextLeaf()
        } else if let newMeasuredOffsetInLeaf {
            if let (mleaf, m) = measuredOffsetOfLeaf, type(of: m) == type(of: metric) {
                measuredPosition = (mleaf + newMeasuredOffsetInLeaf, metric)
            } else {
                let mleaf = measure(upToLeafContaining: offsetOfLeaf, using: metric)
                measuredOffsetOfLeaf = (mleaf, metric)
                measuredPosition = (mleaf + newMeasuredOffsetInLeaf, metric)
            }
            position = offsetOfLeaf + newOffsetInLeaf
        } else {
            measuredPosition = nil
            position = offsetOfLeaf + newOffsetInLeaf
        }

        return position
    }

    // Moves to the start of the previous leaf, regardless of offsetInLeaf.
    @discardableResult
    mutating func prevLeaf() -> (BTree.Leaf, Int)? {
        assert(root != nil)

        if leaf == nil {
            return nil
        }

        // if we're in the first leaf, there is no previous leaf.
        if offsetOfLeaf == 0 {
            invalidate()
            return nil
        }

        // ascend until we can go left
        while let el = path.last, el.slot == 0 {
            path.removeLast()
        }

        // move left
        path[path.count - 1].slot -= 1

        var node = path[path.count - 1].child

        // descend right
        while !node.isLeaf {
            path.append(BTree.PathElement(node: node, slot: node.children.count - 1))
            node = node.children[node.children.count - 1]
        }

        let leaf = node.leaf
        self.leaf = leaf
        self.offsetOfLeaf -= leaf.count
        self.position = offsetOfLeaf
        self.measuredPosition = nil
        self.measuredOffsetOfLeaf = nil

        return read()
    }

    @discardableResult
    mutating func nextLeaf() -> (BTree.Leaf, Int)? {
        assert(root != nil)

        guard let leaf else {
            return nil
        }

        self.position = offsetOfLeaf + leaf.count

        if position == root!.count {
            invalidate()
            return nil
        }

        // ascend until we can go right
        while let el = path.last, el.slot == el.node.children.count - 1 {
            path.removeLast()
        }

        // move right
        path[path.count - 1].slot += 1

        var node = path[path.count - 1].child

        // descend left
        while !node.isLeaf {
            path.append(BTree.PathElement(node: node, slot: 0))
            node = node.children[0]
        }

        self.leaf = node.leaf
        self.offsetOfLeaf = position
        self.measuredPosition = nil
        self.measuredOffsetOfLeaf = nil

        return read()
    }

    func peekPrevLeaf() -> (BTree.Leaf, Int)? {
        var i = self
        return i.prevLeaf()
    }

    func peekNextLeaf() -> (BTree.Leaf, Int)? {
        var i = self
        return i.nextLeaf()
    }

    mutating func floorLeaf() -> BTree.Leaf? {
        assert(root != nil)

        guard let leaf else {
            return nil
        }

        measuredPosition = nil

        position = offsetOfLeaf
        return leaf
    }

    func measure<M>(upToLeafContaining pos: Int, using metric: M) -> Int where M: BTreeMetric<Summary> {
        if pos == 0 {
            return 0
        }

        var node = root!
        var measure = 0
        var pos = pos

        while !node.isLeaf {
            for child in node.children {
                if pos < child.count {
                    node = child
                    break
                }
                pos -= child.count
                measure += child.measure(using: metric)
            }
        }

        return measure
    }

    mutating func descend<M>(toLeafContaining measure: Int, asMeasuredBy metric: M) where M: BTreeMetric<Summary> {
        var node = root!
        var offset = 0
        var measuredOffset = 0
        var measure = measure

        path = []

        while !node.isLeaf {
            var slot = 0
            for child in node.children.dropLast() {
                let childMeasure = child.measure(using: metric)
                if measure <= childMeasure {
                    break
                }
                offset += child.count
                measure -= childMeasure
                measuredOffset += childMeasure
                slot += 1
            }
            path.append(BTree.PathElement(node: node, slot: slot))
            node = node.children[slot]
        }

        self.leaf = node.leaf
        self.position = offset
        self.offsetOfLeaf = offset
        self.measuredOffsetOfLeaf = (measuredOffset, metric)
    }

    func validate(for root: BTree.Node) {
        precondition(self.root === root)
        precondition(self.mutationCount == root.mutationCount)
        precondition(self.leaf != nil)
    }

    func validate(_ other: Self) {
        precondition(root === other.root && root != nil)
        precondition(mutationCount == root!.mutationCount)
        precondition(mutationCount == other.mutationCount)
        precondition(leaf != nil && other.leaf != nil)
    }

    func read() -> (BTree.Leaf, Int)? {
        guard let leaf else {
            return nil
        }

        return (leaf, offsetInLeaf)
    }

    mutating func invalidate() {
        self.leaf = nil
        self.offsetOfLeaf = -1
        self.measuredPosition = nil
        self.measuredOffsetOfLeaf = nil
    }
}

extension BTree.Index: Comparable {
    static func < (left: BTree.Index, right: BTree.Index) -> Bool {
        left.validate(right)
        return left.position < right.position
    }

    static func == (left: BTree.Index, right: BTree.Index) -> Bool {
        left.validate(right)
        return left.position == right.position
    }
}
