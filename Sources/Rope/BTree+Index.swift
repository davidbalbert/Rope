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


    // TODO: do we have to disambiguate between "at the end" and invalid? Maybe? I'm hoping we can just throw an error rather than have an invalid state. I.e. If we're at position 0, and we try to go back to the previous character, can't we just throw an error?
    // TODO: if we're at the end, position should be == root!.count
    //
    // If we were to disambiguate, here's an idea: Leaf is always present.
    // We're at the end if position == root!.count. For every leaf besides
    // the final leaf, offsetInLeaf cannot equal leaf.count. This is only
    // allowed for endIndex where offsetInLeaf == leaf.count.
    struct Index {
        weak var root: Node?
        let mutationCount: Int

        var position: Int

        var path: [PathElement]

        var leaf: Leaf? // Nil if we're at the end of the tree. Otherwise, present.
        var offsetOfLeaf: Int // Position of the first element of the leaf in base units. -1 if we're at the end of the tree.

        var offsetInLeaf: Int {
            position - offsetOfLeaf
        }

        fileprivate init(atNonEndOffset position: Int, in root: Node) {
            assert((root.isEmpty && position == 0) || (0..<root.count).contains(position))

            self.root = root
            self.mutationCount = root.mutationCount
            self.position = position
            self.path = []
            self.leaf = nil
            self.offsetOfLeaf = 0

            descend()
        }

        // TODO: we could write this in terms of descend(toLeafContaining:asMeasuredBy:) using the
        // base metric. Remember that we'll need to save our position before calling the above
        // function, and then reset it after calling the function. Otherwise, we'll always end
        // up at the beginning of the leaf.
        mutating func descend() {
            path = []
            var node = root! // assume we have a root
            var offset = 0
            while !node.isLeaf {
                var slot = 0
                for child in node.children {
                    if offset + child.count > position {
                        break
                    }
                    offset += child.count
                    slot += 1
                }
                path.append(PathElement(node: node, slot: slot))
                node = node.children[slot]
            }

            self.leaf = node.leaf
            self.offsetOfLeaf = offset
        }

        init(offsetBy offset: Int, in root: Node) {
            precondition((0...root.count).contains(offset), "Index out of bounds")

            // endIndex is special cased because we don't to a leaf.
            if offset == root.count {
                self.init(endOf: root)
            } else {
                self.init(atNonEndOffset: offset, in: root)
            }
        }

        init(startOf root: Node) {
            self.init(atNonEndOffset: 0, in: root)
        }

        init(endOf root: Node) {
            self.root = root
            self.mutationCount = root.mutationCount

            self.position = root.count
            self.path = []

            self.leaf = nil
            self.offsetOfLeaf = -1
        }

        var isAtEnd: Bool {
            return leaf == nil
        }

        @discardableResult
        mutating func prev(using metric: some BTreeMetric<Summary>) -> Int? {
            assert(root != nil)

            if position == 0 {
                return nil
            }

            if let offset = prev(withinLeafUsing: metric) {
                return offset
            }

            if prevLeaf() == nil {
                // the leaf we started on was the first leaf, and we didn't
                // find a boundary, so now we're at the beginning.
                return nil
            }

            // prevLeaf() puts us at the beginning of the previous leaf. We need
            // to move one past the end.
            //
            // WARNING: after this line, we're in an invalid state until we call
            // prev(withinLeafUsing:).
            position = offsetOfLeaf + leaf!.count

            // one more shot
            if let offset = prev(withinLeafUsing: metric) {
                return offset
            }

            // The leaf before the starting leaf had no boundaries in the metric.
            // Just start at the top and descend instead.
            let measure = measure(upTo: offsetOfLeaf, using: metric)
            descend(toLeafContaining: measure, asMeasuredBy: metric)

            position = offsetOfLeaf + leaf!.count
            if let offset = prev(withinLeafUsing: metric) {
                return offset
            }

            // we're at the beginning
            assert(position == 0)
            return nil
        }

        @discardableResult
        mutating func next(using metric: some BTreeMetric<Summary>) -> Int? {
            assert(root != nil)

            if position == root!.count {
                return nil
            }

            if let offset = next(withinLeafUsing: metric) {
                return offset
            }

            if nextLeaf() == nil {
                // the leaf we started on was the last leaf, and we didn't
                // find a boundary, so now we're at the end.
                return nil
            }

            // one more shot
            if let offset = next(withinLeafUsing: metric) {
                return offset
            }

            // If we get here, the leaf after the one we started has no boundaries
            // in the metric. Just start at the top and descend instead.

            // measure the our current position
            let measure = measure(upTo: offsetOfLeaf, using: metric)
            descend(toLeafContaining: measure+1, asMeasuredBy: metric)

            if let offset = next(withinLeafUsing: metric) {
                return offset
            }

            // we're at the end
            assert(position == root!.count)
            leaf = nil
            offsetOfLeaf = -1
            return nil
        }

        mutating func prev(withinLeafUsing metric: some BTreeMetric<Summary>) -> Int? {
            assert(root != nil)

            if position == root!.count {
                assert(leaf == nil)
                prevLeaf()

                // prevLeaf() puts us at the beginning of the previous leaf. We need
                // to move one past the end.
                //
                // WARNING: after this line, we're in an invalid state until we call
                // prev(withinLeafUsing:).
                position = root!.count
            }

            let leaf = leaf!

            guard let newOffsetInLeaf = metric.prev(offsetInLeaf, in: leaf) else {
                return nil
            }

            position = offsetOfLeaf + newOffsetInLeaf

            if position == 0 {
                return nil
            }

            return position
        }

        mutating func next(withinLeafUsing metric: some BTreeMetric<Summary>) -> Int? {
            assert(root != nil)
            let leaf = leaf!

            guard let newOffsetInLeaf = metric.next(offsetInLeaf, in: leaf) else {
                return nil
            }

            // TODO: is it possible that this is only true for leading boundaries? If so
            // do we need it? Right now, we only have trailing boundaries.
            if newOffsetInLeaf == leaf.count && offsetOfLeaf + newOffsetInLeaf != root!.count {
                nextLeaf()
            } else {
                position = offsetOfLeaf + newOffsetInLeaf
            }

            if position == root!.count {
                return nil
            }

            return position
        }

        @discardableResult
        mutating func prevLeaf() -> (Leaf, Int)? {
            assert(root != nil)

            if position == 0 {
                return nil
            }

            if position == root!.count {
                // we're at the end, go to the start of the last leaf
                position -= 1
                descend()
                position = offsetOfLeaf
                return read()
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
                path.append(PathElement(node: node, slot: node.children.count - 1))
                node = node.children[node.children.count - 1]
            }

            self.offsetOfLeaf -= node.count
            self.position = offsetOfLeaf
            self.leaf = node.leaf
            return read()
        }

        @discardableResult
        mutating func nextLeaf() -> (Leaf, Int)? {
            assert(root != nil)

            // Can't advance past endIndex
            guard let leaf else {
                // TODO: make detecting end of tree more sane and uniform.
                // It should just depend on position. Maybe add an enum
                // that stores valid(position, leaf, offsetOfLeaf) and end(position).
                return nil
            }

            self.position = offsetOfLeaf + leaf.count

            if position == root!.count {
                self.path = []
                self.leaf = nil
                self.offsetOfLeaf = -1
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
                path.append(PathElement(node: node, slot: 0))
                node = node.children[0]
            }

            self.offsetOfLeaf = position
            self.leaf = node.leaf
            return read()
        }
        
        func peekPrevLeaf() -> (Leaf, Int)? {
            var i = self
            return i.prevLeaf()
        }

        func peekNextLeaf() -> (Leaf, Int)? {
            var i = self
            return i.nextLeaf()
        }

        func measure(upTo pos: Int, using metric: some BTreeMetric<Summary>) -> Int {
            var node = root!
            var measure = 0
            var offset = pos

            while !node.isLeaf {
                for child in node.children {
                    if offset < child.count {
                        node = child
                        break
                    }
                    offset -= child.count
                    measure += metric.measure(summary: child.summary, count: child.count)
                }
            }

            if offset > 0 {
                measure += metric.measure(summary: node.summary, count: offset)
            }

            return measure
        }

        mutating func descend(toLeafContaining measure: Int, asMeasuredBy metric: some BTreeMetric<Summary>) {
            var node = root!
            var offset = 0
            var measure = measure

            path = []

            while !node.isLeaf {
                var slot = 0
                for child in node.children.dropLast() {
                    let childMeasure = metric.measure(summary: child.summary, count: child.count)
                    if childMeasure >= measure {
                        break
                    }
                    offset += child.count
                    measure -= childMeasure
                    slot += 1
                }
                path.append(PathElement(node: node, slot: slot))
                node = node.children[slot]
            }

            self.leaf = node.leaf
            self.position = offset
            self.offsetOfLeaf = offset
        }

        func validate(for root: Node) {
            precondition(self.root === root)
            precondition(self.mutationCount == root.mutationCount)
        }

        func validate(_ other: Index) {
            precondition(root === other.root && root != nil)
            precondition(mutationCount == root!.mutationCount)
            precondition(mutationCount == other.mutationCount)
        }

        func read() -> (Leaf, Int)? {
            guard let leaf else {
                return nil
            }

            return (leaf, offsetInLeaf)
        }
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
