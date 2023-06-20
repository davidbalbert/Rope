//
//  Node.swift
//  
//
//  Created by David Albert on 6/12/23.
//

import Foundation

extension Rope {
    enum NodeValue {
        case `internal`([Node])
        case leaf(String)

        var children: [Node] {
            if case let .internal(children) = self {
                return children
            } else {
                fatalError("children called on a leaf node")
            }
        }

        var string: String {
            if case let .leaf(s) = self {
                return s
            } else {
                fatalError("string called on leaf node")
            }
        }

        mutating func withMutableChildren(block: (inout [Node]) -> Void) {
            guard case .internal(var children) = self else {
                fatalError("withMutableChildren called on a leaf node")
            }

            block(&children)
            self = .internal(children)
        }

        mutating func withMutableLeaf(block: (inout String) -> Void) {
            guard case .leaf(var leaf) = self else {
                fatalError("withMutableLeaf called on an internal node")
            }

            block(&leaf)
            self = .leaf(leaf)
        }
    }

    class Node {
        var height: Int
        var mutationCount: Int
        var count: Int
        var value: NodeValue

        #if DEBUG
        var cloneCount: Int = 0
        #endif

        var isEmpty: Bool {
            count == 0
        }

        var children: [Node] {
            value.children
        }

        var string: String {
            value.string
        }

        init(height: Int, count: Int, value: NodeValue) {
            self.height = height
            self.mutationCount = 0
            self.count = count
            self.value = value

            #if DEBUG
            self.cloneCount = 0
            #endif
        }

        init(cloning node: Node) {
            self.height = node.height
            self.mutationCount = node.mutationCount
            self.count = node.count
            self.value = node.value

            #if DEBUG
            self.cloneCount = node.cloneCount + 1
            #endif
        }

        convenience init(_ children: [Node]) {
            assert(1 <= children.count && children.count <= maxChild)
            let height = children[0].height + 1
            var count = 0

            for child in children {
                assert(child.height + 1 == height)
                assert(child.atLeastMinSize)
                count += child.count
            }

            self.init(height: height, count: count, value: .internal(children))

            #if DEBUG

            #endif
        }

        convenience init<C>(_ children: C) where C: Sequence, C.Element == Node {
            self.init(Array(children))
        }

        convenience init<C1, C2>(children leftChildren: C1, mergedWith rightChildren: C2) where C1: Collection, C2: Collection, C1.Element == Node, C1.Element == C2.Element {
            let count = leftChildren.count + rightChildren.count
            let children = [AnySequence(leftChildren), AnySequence(rightChildren)].joined()

            if count <= maxChild {
                self.init(children)
            } else {
                let split = count / 2
                let left = Node(children.prefix(split))
                let right = Node(children.dropFirst(split))
                self.init([left, right])
            }
        }

        convenience init<S>(_ seq: S) where S: Collection, S.Element == Node {
            self.init(Array(seq))
        }

        convenience init(_ string: String) {
            assert(string.count <= maxLeaf)
            self.init(height: 0, count: string.count, value: .leaf(string))
        }

        convenience init() {
            self.init("")
        }

        var isLeaf: Bool {
            return height == 0
        }

        var atLeastMinSize: Bool {
            if isLeaf {
                return count >= minLeaf
            } else {
                return count >= minChild
            }
        }

        // Mutating. Self must be unique at this point.
        func concatinate(_ other: Node) -> Node {
            let h1 = height
            let h2 = other.height

            if h1 < h2 {
                if h1 == h2 - 1 && atLeastMinSize {
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
                if atLeastMinSize && other.atLeastMinSize {
                    return Node([self, other])
                } else if h1 == 0 {
                    // Mutates self, but because concatinate requires a unique
                    // self, we know self is already unique at this point.
                    return merge(withLeaf: other)
                } else {
                    return Node(children: children, mergedWith: other.children)
                }
            } else {
                if h2 == h1 - 1 && other.atLeastMinSize {
                    return Node(children: children, mergedWith: [other])
                }

                // Because concatinate is mutating, we need to make sure that
                // children.last is unique before calling.

                withMutableChildren { children in
                    if !isKnownUniquelyReferenced(&children[children.count-1]) {
                        children[children.count-1] = children[children.count-1].clone()
                    }
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

            if atLeastMinSize && other.atLeastMinSize {
                return Node([self, other])
            }

            let newLeaf = pushLeaf(possiblySplitting: other.string)
            if let newLeaf {
                return Node([self, newLeaf])
            } else {
                return self
            }
        }

        // Mutating. Self must be unique at this point.
        func pushLeaf(possiblySplitting s: String) -> Node? {
            assert(isLeaf)

            mutationCount &+= 1

            withMutableLeaf { string in
                string += s
            }

            if string.count <= maxLeaf {
                count = string.count
                return nil
            } else {
                // TODO: split at newline boundary if we can
                let splitPoint = string.index(string.startIndex, offsetBy: Swift.max(minLeaf, string.count - maxLeaf))
                let split = String(string[splitPoint...])

                withMutableLeaf { string in
                    string = String(string[..<splitPoint])
                }
                count = string.count
                return Node(split)
            }
        }

        func clone() -> Node {
            // All properties are value types, so it's sufficient
            // to just create a new Node instance.
            return Node(cloning: self)
        }

        func withMutableLeaf(block: (inout String) -> Void) {
            value.withMutableLeaf(block: block)
        }

        func withMutableChildren(block: (inout [Node]) -> Void) {
            value.withMutableChildren(block: block)
        }
    }
}
