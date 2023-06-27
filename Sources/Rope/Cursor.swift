//
//  Cursor.swift
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
    // Maybe call this Cursor
    struct Cursor {
        weak var root: Node?
        let mutationCount: Int

        var position: Int

        var path: [PathElement]

        var leaf: Leaf? // Nil if we're at the end of the rope. Otherwise, present.
        var leafStart: Int // Position of the first element of the leaf in base units. -1 if we're at the end of the tree.

        var offsetInLeaf: Int {
            position - leafStart
        }

        fileprivate init(atNonEndOffset position: Int, in tree: BTree) {
            assert((tree.isEmpty && position == 0) || (0..<tree.count).contains(position))

            self.root = tree.root
            self.mutationCount = tree.root.mutationCount
            self.position = position
            self.path = []
            self.leaf = nil
            self.leafStart = 0

            descend()
        }

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
            self.leafStart = offset
        }

        init(offsetBy offset: Int, in tree: BTree) {
            precondition((0...tree.count).contains(offset), "Index out of bounds")

            // endIndex is special cased because we don't to a leaf.
            if offset == tree.count {
                self.init(endOf: tree)
            } else {
                self.init(atNonEndOffset: offset, in: tree)
            }
        }

        init(startOf tree: BTree) {
            self.init(atNonEndOffset: 0, in: tree)
        }

        init(endOf tree: BTree) {
            self.root = tree.root
            self.mutationCount = tree.root.mutationCount

            self.position = tree.count
            self.path = []

            self.leaf = nil
            self.leafStart = -1
        }

        var isAtEnd: Bool {
            return leaf == nil
        }

        mutating func formSuccessor() {
            guard let leaf else {
                preconditionFailure("Cannot advance past endIndex")
            }

            // next_inside_leaf()
            if offsetInLeaf < leaf.count {
                self.position += 1
                return
            }

            // move to the next leaf
            while let el = path.last, el.slot == el.node.children.count - 1 {
                path.removeLast()
            }

            if path.isEmpty {
                self.leaf = nil
                self.leafStart = -1
                return
            }

            path[path.count - 1].slot += 1
            var node = path[path.count - 1].child

            // descend
            while !node.isLeaf {
                path.append(PathElement(node: node, slot: 0))
                node = node.children[0]
            }

            // move position to the start of the next leaf
            position += 1

            self.leafStart = position
            self.leaf = node.leaf
        }

        mutating func formPredecessor() {
            if position == 0 {
                preconditionFailure("Cannot go below startIndex")
            }

            guard let leaf else {
                // we're at endIndex
                // warning: if we change invariants later, leaf being nil may
                // no longer mean that position == root.count.
                position -= 1
                descend()
                return
            }

            if offsetInLeaf > 1 {
                position -= 1
                return
            }

            // move to the previous leaf
            while let el = path.last, el.slot == 0 {
                path.removeLast()
            }

            // descend
            path[path.count - 1].slot -= 1
            var node = path[path.count - 1].child

            while !node.isLeaf {
                path.append(PathElement(node: node, slot: node.children.count - 1))
                node = node.children[node.children.count - 1]
            }

            self.leaf = node.leaf
            self.leafStart = position - leaf.count
            position -= 1
        }

        func validate(for root: Node) {
            precondition(self.root === root)
            precondition(self.mutationCount == root.mutationCount)
        }

        func validate(_ other: Cursor) {
            precondition(root === other.root && root != nil)
            precondition(mutationCount == root!.mutationCount)
            precondition(mutationCount == other.mutationCount)
        }

        func read(for tree: BTree) -> (Leaf, Int)? {
            validate(for: tree.root)

            guard let leaf else {
                return nil
            }

            return (leaf, offsetInLeaf)
        }
    }
}

extension BTree.Cursor: Comparable {
    static func < (left: BTree.Cursor, right: BTree.Cursor) -> Bool {
        left.validate(right)
        return left.position < right.position
    }

    static func == (left: BTree.Cursor, right: BTree.Cursor) -> Bool {
        left.validate(right)
        return left.position == right.position
    }
}
