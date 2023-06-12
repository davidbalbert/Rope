//
//  Node.swift
//  
//
//  Created by David Albert on 6/12/23.
//

import Foundation

extension Rope {
    class Node {
        var height: Int
        var mutationCount: Int
        var count: Int
        var children: [Rope.Node]
        var string: String // always empty for internal nodes

        init (_ height: Int, _ count: Int, _ children: [Node], _ string: String) {
            self.height = height
            self.mutationCount = 0
            self.count = count
            self.children = children
            self.string = string
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

            self.init(height, count, children, "")
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
            self.init(0, string.count, [], string)
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

        // Mutates self if self is a leaf. In that situation,
        // self must be unique by this point.
        func concatinate(_ other: Node) -> Node {
            let h1 = height
            let h2 = other.height

            if h1 < h2 {
                if h1 == h2 - 1 && atLeastMinSize {
                    return Node(children: [self], mergedWith: other.children)
                }

                // TODO: xi has right.children[0].clone(). Is that necessary here?
                // I don't think so because I don't think it's possible for concatinate
                // to modify other.children[0].
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
                    // Mutates self, but we only call concatinate with a unique self,
                    // so we should be fine.
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
                ensureUniqueChild(at: children.count - 1)

                let new = children[children.count - 1].concatinate(other)
                if new.height == h1 - 1 {
                    return Node(children: children.dropLast(), mergedWith: [new])
                } else {
                    return Node(children: children.dropLast(), mergedWith: new.children)
                }
            }
        }

        // Mutates self. Self must be unique at this point
        func insert(_ c: Character, at position: Int) -> Node? {
            mutationCount &+= 1

            if isLeaf {
                if count < maxLeaf {
                    string.insert(c, at: string.index(string.startIndex, offsetBy: position))
                    count += 1
                    return nil
                } else {
                    let mid = string.index(string.startIndex, offsetBy: minLeaf+1)
                    let left = Rope.Node(String(string[..<mid]))
                    let right = Rope.Node(String(string[mid...]))
                    let node = Rope.Node(1, count, [left, right], "")
                    return node.insert(c, at: position) ?? node
                }
            } else {
                if count < maxChild {
                    // find the child that contains the position
                    var pos = position
                    var i = 0

                    // we assume that the position is valid, so we don't check to see
                    // if we go past the end of the children.
                    while pos >= children[i].count {
                        pos -= children[i].count
                        i += 1
                    }

                    ensureUniqueChild(at: i)
                    if let node = children[i].insert(c, at: pos) {
                        children[i] = node
                    }

                    count += 1
                    return nil
                } else {
                    let mid = minChild
                    let left = Node(children[..<mid])
                    let right = Node(children[mid...])
                    let node = Node([left, right])
                    return node.insert(c, at: position) ?? node
                }
            }
        }

        func ensureUniqueChild(at index: Int) {
            if !isKnownUniquelyReferenced(&children[index]) {
                children[index] = children[index].clone()
            }
        }

        func clone() -> Node {
            // All properties are value types, so it's sufficient
            // to just create a new Node instance.
            return Node(height, count, children, string)
        }

        // Can mutate self. Must be called with a unique self.
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

        // Mutating. Must be called on a non-shared node.
        func pushLeaf(possiblySplitting s: String) -> Node? {
            assert(isLeaf)

            string += s

            if string.count <= maxLeaf {
                count = string.count
                return nil
            } else {
                // TODO: split at newline boundary if we can
                let splitPoint = string.index(string.startIndex, offsetBy: Swift.max(minLeaf, string.count - maxLeaf))
                let split = String(string[splitPoint...])
                string = String(string[..<splitPoint])
                count = string.count
                return Node(split)
            }
        }
    }
}
