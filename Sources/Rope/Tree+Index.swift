//
//  Tree+Index.swift
//
//
//  Created by David Albert on 6/13/23.
//

import Foundation

extension Tree {
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

        var current: Node // Root if we're at the end of the rope. Otherwise, a leaf.
        var idx: Leaf.Index? // nil if we're at the end of the rope.

        init(atNonEndOffset position: Int, in root: Node) {
            assert((root.isEmpty && position == 0) || (0..<root.count).contains(position))

            self.root = root
            self.mutationCount = root.mutationCount
            self.position = position
            self.path = []

            var node = root
            var pos = position
            while !node.isLeaf {
                var slot = 0
                var offset = 0
                for child in node.children {
                    if offset + child.count > pos {
                        break
                    }
                    offset += child.count
                    slot += 1
                }
                path.append(PathElement(node: node, slot: slot))
                node = node.children[slot]
                pos -= offset
            }

            self.current = node
            self.idx = node.leaf.index(node.leaf.startIndex, offsetBy: pos)
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
            self.position = root.count
            self.mutationCount = root.mutationCount
            self.path = []
            self.current = root
            self.idx = nil
        }

        var isAtEnd: Bool {
            return idx == nil
        }

        var value: Leaf.Element? {
            guard let idx else { return nil }
            return current.leaf[idx]
        }

        mutating func formSuccessor() {
            guard var idx else {
                preconditionFailure("Cannot advance past endIndex")
            }

            idx = current.leaf.index(after: idx)

            if idx < current.leaf.endIndex {
                self.idx = idx
            } else {
                while let el = path.last, el.slot == el.node.children.count - 1 {
                    path.removeLast()
                }

                guard !path.isEmpty else {
                    self.idx = nil
                    self.current = root! // assume root is not nil because Rope.index(after:) called validate(for:)
                    return
                }

                path[path.count - 1].slot += 1
                var node = path[path.count - 1].child

                while !node.isLeaf {
                    path.append(PathElement(node: node, slot: 0))
                    node = node.children[0]
                }

                self.current = node
                self.idx = node.leaf.startIndex
            }

            self.position += 1
        }

        mutating func formPredecessor() {
            if idx == current.leaf.startIndex && path.allSatisfy({ $0.slot == 0 }) {
                preconditionFailure("Cannot go below startIndex")
            }

            var i: Leaf.Index
            if let idx {
                i = idx
            } else {
                // we're at endIndex
                var node = current // current == root in this situation
                while !node.isLeaf {
                    path.append(PathElement(node: node, slot: node.children.count - 1))
                    node = node.children[node.children.count - 1]
                }

                current = node
                i = node.leaf.endIndex
            }

            if i != current.leaf.startIndex {
                self.idx = current.leaf.index(before: i)
            } else {
                while let el = path.last, el.slot == 0 {
                    path.removeLast()
                }

                path[path.count - 1].slot -= 1
                var node = path[path.count - 1].child

                while !node.isLeaf {
                    path.append(PathElement(node: node, slot: node.children.count - 1))
                    node = node.children[node.children.count - 1]
                }

                self.current = node
                self.idx = node.leaf.index(before: node.leaf.endIndex)
            }

            position -= 1
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
    }
}

extension Tree.Index: Comparable {
    static func < (left: Tree.Index, right: Tree.Index) -> Bool {
        left.validate(right)
        return left.position < right.position
    }

    static func == (left: Tree.Index, right: Tree.Index) -> Bool {
        left.validate(right)
        return left.position == right.position
    }
}
