//
//  Node.swift
//  
//
//  Created by David Albert on 6/12/23.
//

import Foundation

extension Tree {
    final class Node {
        typealias Leaf = Summary.Leaf

        var height: Int
        var count: Int // in base units

        // children and leaf are mutually exclusive
        var children: [Node]
        var leaf: Leaf

        var mutationCount: Int

        #if DEBUG
        var cloneCount: Int = 0
        #endif

        var isEmpty: Bool {
            count == 0
        }

        init(height: Int, count: Int, children: [Node], leaf: Leaf) {
            self.height = height
            self.mutationCount = 0
            self.count = count
            self.children = children
            self.leaf = leaf

            #if DEBUG
            self.cloneCount = 0
            #endif
        }

        init(cloning node: Node) {
            self.height = node.height
            self.mutationCount = node.mutationCount
            self.count = node.count
            self.children = node.children
            self.leaf = node.leaf

            #if DEBUG
            self.cloneCount = node.cloneCount + 1
            #endif
        }

        convenience init(_ children: [Node]) {
            assert(1 <= children.count && children.count <= Tree.maxChild)
            let height = children[0].height + 1
            var count = 0

            for child in children {
                assert(child.height + 1 == height)
                assert(!child.isUndersized)
                count += child.count
            }

            self.init(height: height, count: count, children: children, leaf: Leaf())
        }

        convenience init<C>(_ children: C) where C: Sequence, C.Element == Node {
            self.init(Array(children))
        }

        convenience init<C1, C2>(children leftChildren: C1, mergedWith rightChildren: C2) where C1: Collection, C2: Collection, C1.Element == Node, C1.Element == C2.Element {
            let count = leftChildren.count + rightChildren.count
            let children = [AnySequence(leftChildren), AnySequence(rightChildren)].joined()

            if count <= Tree.maxChild {
                self.init(children)
            } else {
                let split = count / 2
                let left = Node(children.prefix(split))
                let right = Node(children.dropFirst(split))
                self.init([left, right])
            }
        }

        convenience init(_ leaf: Leaf) {
            self.init(height: 0, count: leaf.count, children: [], leaf: leaf)
        }

        convenience init() {
            self.init(Leaf())
        }

        var isLeaf: Bool {
            return height == 0
        }

        var isUndersized: Bool {
            if isLeaf {
                return leaf.isUndersized
            } else {
                return count < minChild
            }
        }

        // Mutating. Self must be unique at this point.
        func concatinate(_ other: Node) -> Node {
            let h1 = height
            let h2 = other.height

            if h1 < h2 {
                if h1 == h2 - 1 && !isUndersized {
                    return Node(children: [self], mergedWith: other.children)
                }

                // Concatinate mutates self, but self is already guaranteed to be
                // unique at this point.
                let new = concatinate(other.children[0])
                if new.height == h2 - 1 {
                    return Node(children: [new], mergedWith: other.children.dropFirst())
                } else {
                    return Node(children: new.children, mergedWith: other.children.dropFirst())
                }
            } else if h1 == h2 {
                if !isUndersized && !other.isUndersized {
                    return Node([self, other])
                } else if h1 == 0 {
                    // Mutates self, but because concatinate requires a unique
                    // self, we know self is already unique at this point.
                    return merge(withLeaf: other)
                } else {
                    return Node(children: children, mergedWith: other.children)
                }
            } else {
                if h2 == h1 - 1 && !other.isUndersized {
                    return Node(children: children, mergedWith: [other])
                }

                // Because concatinate is mutating, we need to make sure that
                // children.last is unique before calling.
                if !isKnownUniquelyReferenced(&children[children.count-1]) {
                    mutationCount &+= 1
                    children[children.count-1] = children[children.count-1].clone()
                }

                let new = children[children.count - 1].concatinate(other)
                if new.height == h1 - 1 {
                    return Node(children: children.dropLast(), mergedWith: [new])
                } else {
                    return Node(children: children.dropLast(), mergedWith: new.children)
                }
            }
        }

        // Mutating. Self must be unique at this point.
        func merge(withLeaf other: Node) -> Node {
            assert(isLeaf && other.isLeaf)

            if !isUndersized && !other.isUndersized {
                return Node([self, other])
            }

            mutationCount &+= 1

            let newLeaf = leaf.push(possiblySplitting: other.leaf)
            if let newLeaf {
                return Node([self, Node(newLeaf)])
            } else {
                count = leaf.count
                return self
            }
        }

        func clone() -> Node {
            // All properties are value types, so it's sufficient
            // to just create a new Node instance.
            return Node(cloning: self)
        }
    }
}
