//
//  Builder.swift
//  
//
//  Created by David Albert on 6/12/23.
//

import Foundation

extension Rope {
    struct Builder {
        typealias PartialTree = (node: Node, isUnique: Bool)

        // the inner array always has at least one element
        var stack: [[PartialTree]] = []

        mutating func push(_ node: inout Node) {
            var isUnique = isKnownUniquelyReferenced(&node)
            var n = node

            while true {
                if let (lastNode, _) = stack.last?.last, lastNode.height < n.height {
                    var popped: Node
                    (popped, isUnique) = pop()

                    if !isUnique && popped.isLeaf {
                        popped = popped.clone()
                    }

                    n = popped.concatinate(n)
                    isUnique = true
                } else if var (lastNode, _) = stack.last?.last, lastNode.height == n.height {
                    if lastNode.atLeastMinSize && n.atLeastMinSize {
                        stack[stack.count - 1].append((n, isUnique))
                    } else if n.height == 0 { // lastNode and n are both leafs
                        // This is here (rather than in the pattern match in the else if) because
                        // we can't do `if (var lastNode, let lastNodeIsUnique)`, and if they're both
                        // var, then we get a warning.
                        let lastNodeIsUnique = stack.last!.last!.isUnique

                        if !lastNodeIsUnique {
                            lastNode = lastNode.clone()
                            stack[stack.count - 1][stack[stack.count - 1].count - 1] = (lastNode, true)
                        }
                        
                        if let newLeaf = lastNode.pushLeaf(possiblySplitting: n.string) {
                            assert(newLeaf.atLeastMinSize)
                            stack[stack.count - 1].append((newLeaf, true))
                        }
                    } else {
                        let c1 = lastNode.children
                        let c2 = n.children
                        let count = c1.count + c2.count
                        if count <= maxChild {
                            stack[stack.count - 1].append((Node(c1 + c2), true))
                        } else {
                            let split = count / 2
                            let children = [c1, c2].joined()
                            stack[stack.count - 1].append((Node(children.prefix(split)), true))
                            stack[stack.count - 1].append((Node(children.dropFirst(split)), true))
                        }
                    }

                    if stack[stack.count - 1].count < maxChild {
                        break
                    }

                    (n, isUnique) = pop()
                } else {
                    stack.append([(n, isUnique)])
                    break
                }
            }
        }

        mutating func push(_ node: inout Node, slicedBy range: Range<Int>) {
            if range.isEmpty {
                return
            }

            if range == 0..<node.count {
                push(&node)
                return
            }

            if node.isLeaf {
                push(leaf: node.string, slicedBy: range)
            } else {
                var offset = 0
                for i in 0..<node.children.count {
                    if range.upperBound <= offset {
                        break
                    }

                    let childRange = 0..<node.children[i].count
                    let intersection = childRange.clamped(to: range.offset(by: -offset))
                    push(&node.children[i], slicedBy: intersection)
                    offset += node.children[i].count
                }
            }
        }

        mutating func push(leaf: String) {
            var n = Node(leaf)
            push(&n)
        }

        mutating func push(leaf: String, slicedBy range: Range<Int>) {
            let start = leaf.index(leaf.startIndex, offsetBy: range.lowerBound)
            let end = leaf.index(leaf.startIndex, offsetBy: range.upperBound)

            push(leaf: String(leaf[start..<end]))
        }

        mutating func push(string s: String) {
            if s.isEmpty {
                return
            }

            if s.count <= maxLeaf {
                push(leaf: s)
            } else {
                var i = s.startIndex
                while i < s.endIndex {
                    // TODO: we could pick a better length, e.g. by looking for the next
                    // newline.
                    let chunk = s[i...].prefix(minLeaf)
                    i = chunk.endIndex
                    push(leaf: String(chunk))
                }
            }
        }

        mutating func pop() -> PartialTree {
            let partialTrees = stack.removeLast()
            if partialTrees.count == 1 {
                return partialTrees[0]
            } else {
                // We are able to throw away isUnique for all our children, because
                // inside Builder, we only care about the uniqueness of the nodes
                // directly on teh stack.
                //
                // In general, we do still care if some nodes are unique – specifically
                // when concatinating two nodes, the rightmost branch of the left tree
                // in the concatination is being mutated during the graft, so it needs to
                // be unique, but we take care of that in Node.concatinate.
                return (Node(partialTrees.map(\.node)), true)
            }
        }

        mutating func build() -> Node {
            if stack.isEmpty {
                return Node()
            } else {
                var (n, _) = pop()
                while !stack.isEmpty {
                    var (popped, isUnique) = pop()
                    if !isUnique && popped.isLeaf {
                        popped = popped.clone()
                    }

                    n = popped.concatinate(n)
                }

                return n
            }
        }
    }
}
