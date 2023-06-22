//
//  Node.swift
//  
//
//  Created by David Albert on 6/12/23.
//

import Foundation

extension Tree {
    enum NodeValue {
        case `internal`([Node])
        case leaf(Summary.Leaf)

        var children: [Node] {
            _read {
                guard case .internal(let children) = self else {
                    fatalError("children called on a leaf node")
                }
                
                yield children
            }
            _modify {
                guard case .internal(var children) = self else {
                    fatalError("children called on a leaf node")
                }
                
                yield &children
            }
        }

        var leaf: Summary.Leaf {
            _read {
                guard case .leaf(let leaf) = self else {
                    fatalError("leaf called on an internal node")
                }

                yield leaf
            }
            _modify {
                guard case .leaf(var leaf) = self else {
                    fatalError("leaf called on an internal node")
                }

                yield &leaf
            }
        }

        mutating func withMutableChildren<R>(block: (inout [Node]) -> R) -> R {
            guard case .internal(var children) = self else {
                fatalError("withMutableChildren called on a leaf node")
            }

            // I considered adding a .null case and doing the following
            // to ensure that children has only one reference, but it seems
            // the compiler is smart enough to not need it. As far as I
            // can tell, the compiler doesn't add a retain, so children
            // gets mutated in place.
            //
            // See this for more: https://forums.swift.org/t/appending-to-an-array-stored-in-an-enum-case-payload-o-1-or-o-n/56716
            // self = .null
            let ret = block(&children)
            self = .internal(children)

            return ret
        }

        mutating func withMutableLeaf<R>(block: (inout Summary.Leaf) -> R) -> R {
            guard case .leaf(var leaf) = self else {
                fatalError("withMutableLeaf called on an internal node")
            }

            // See above comment for why self = .null isn't necessary.
            // self = .null
            let ret = block(&leaf)
            self = .leaf(leaf)

            return ret
        }
    }

    final class Node {
        typealias Leaf = Summary.Leaf

        var height: Int
        var count: Int // in base units
        var value: NodeValue
        var mutationCount: Int

        #if DEBUG
        var cloneCount: Int = 0
        #endif

        var isEmpty: Bool {
            count == 0
        }

        var children: [Node] {
            _read {
                yield value.children
            }
            _modify {
                yield &value.children
            }
        }

        var leaf: Summary.Leaf {
            _read {
                yield value.leaf
            }
            _modify {
                yield &value.leaf
            }
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
            assert(1 <= children.count && children.count <= Tree.maxChild)
            let height = children[0].height + 1
            var count = 0

            for child in children {
                assert(child.height + 1 == height)
                assert(!child.isUndersized)
                count += child.count
            }

            self.init(height: height, count: count, value: .internal(children))
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
            self.init(height: 0, count: leaf.count, value: .leaf(leaf))
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

                withMutableChildren { children in
                if !isKnownUniquelyReferenced(&children[children.count-1]) {
                    mutationCount &+= 1
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

            if !isUndersized && !other.isUndersized {
                return Node([self, other])
            }

            mutationCount &+= 1

            var newLeaf: Leaf?
            withMutableLeaf { leaf in
                newLeaf = leaf.push(possiblySplitting: other.leaf)
            }

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

        func withMutableLeaf<R>(block: (inout Leaf) -> R) -> R {
            value.withMutableLeaf(block: block)
        }

        func withMutableChildren<R>(block: (inout [Node]) -> R) -> R{
            value.withMutableChildren(block: block)
        }
    }
}
