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

        // Can mutate left because mergeLeaves can mutate left.
        // Left must be guaranteed unique here.
        static func concat(_ left: Node, _ right: Node) -> Node {
            let h1 = left.height
            let h2 = right.height

            if h1 < h2 {
                if h1 == h2 - 1 && left.atLeastMinSize {
                    return mergeChildren([left], right.children)
                }

                // TODO: xi has right.children[0].clone(). Is that necessary here?
                // I don't think so because I don't think it's possible for concat
                // to modify right.
                let new = concat(left, right.children[0])
                if new.height == h2 - 1 {
                    return mergeChildren([new], Array(right.children.dropFirst()))
                } else {
                    return mergeChildren(new.children, Array(right.children.dropFirst()))
                }
            } else if h1 == h2 {
                if left.atLeastMinSize && right.atLeastMinSize {
                    return Node([left, right])
                } else if h1 == 0 {
                    // TODO: this mutates left
                    return mergeLeaves(left, right)
                } else {
                    return mergeChildren(left.children, right.children)
                }
            } else {
                if h2 == h1 - 1 && right.atLeastMinSize {
                    return mergeChildren(left.children, [right])
                }

                // Because concat can mutate left, we need to make sure that
                // left.children.last is unique (or copied) before calling concat.
                left.ensureUniqueChild(at: left.children.count-1)

                let new = concat(left.children.last!, right)
                if new.height == h1 - 1 {
                    return mergeChildren(Array(left.children.dropLast()), [new])
                } else {
                    return mergeChildren(Array(left.children.dropLast()), new.children)
                }
            }
        }

        // Mutates left.
        static func mergeLeaves(_ left: Node, _ right: Node) -> Node {
            assert(left.isLeaf && right.isLeaf)

            if left.atLeastMinSize && right.atLeastMinSize {
                return Node([left, right])
            }

            let newLeaf = left.pushLeaf(possiblySplitting: right.string)
            if let newLeaf {
                return Node([left, newLeaf])
            } else {
                return left
            }
        }

        static func mergeChildren(_ c1: [Node], _ c2: [Node]) -> Node {
            let count = c1.count + c2.count
            if count <= maxChild {
                return Node(c1 + c2)
            } else {
                let split = count / 2
                let children = [c1, c2].joined()
                let left = Node(children.prefix(split))
                let right = Node(children.dropFirst(split))
                return Node([left, right])
            }
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
            if isLeaf {
                return Node(string)
            } else {
                return Node(children)
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
