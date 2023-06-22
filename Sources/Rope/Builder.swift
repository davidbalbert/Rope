//
//  Builder.swift
//  
//
//  Created by David Albert on 6/12/23.
//

import Foundation

extension Tree {
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

                    if !isUnique {
                        popped = popped.clone()
                    }

                    n = popped.concatinate(n)
                    isUnique = true
                } else if var (lastNode, _) = stack.last?.last, lastNode.height == n.height {
                    if lastNode.atLeastMinSize && n.atLeastMinSize {
                        stack[stack.count - 1].append((n, isUnique))
                    } else if n.height == 0 { // lastNode and n are both leafs
                        // TODO: there should be a bump in mutation count somewhere in here.

                        // This is here (rather than in the pattern match in the else if) because
                        // we can't do `if (var lastNode, let lastNodeIsUnique)`, and if they're both
                        // var, then we get a warning.
                        let lastNodeIsUnique = stack.last!.last!.isUnique

                        if !lastNodeIsUnique {
                            lastNode = lastNode.clone()
                            stack[stack.count - 1][stack[stack.count - 1].count - 1] = (lastNode, true)
                        }

                        let newLeaf = lastNode.withMutableLeaf { leaf in
                            leaf.push(possiblySplitting: n.leaf)
                        }

                        lastNode.mutationCount &+= 1
                        lastNode.count = lastNode.leaf.count

                        if let newLeaf {
                            assert(newLeaf.atLeastMinSize)
                            stack[stack.count - 1].append((Node(newLeaf), true))
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
                push(leaf: node.leaf, slicedBy: range)
            } else {
                var offset = 0
                for i in 0..<node.children.count {
                    if range.upperBound <= offset {
                        break
                    }

                    let childRange = 0..<node.children[i].count
                    let intersection = childRange.clamped(to: range.offset(by: -offset))

                    node.withMutableChildren { children in
                        push(&children[i], slicedBy: intersection)
                    }
                    offset += node.children[i].count
                }
            }
        }

        mutating func push(leaf: Leaf) {
            var n = Node(leaf)
            push(&n)
        }

        mutating func push(leaf: Leaf, slicedBy range: Range<Int>) {
            let start = leaf.index(leaf.startIndex, offsetBy: range.lowerBound)
            let end = leaf.index(start, offsetBy: range.upperBound - range.lowerBound)

            push(leaf: leaf[start..<end])
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
                    if !isUnique {
                        popped = popped.clone()
                    }

                    n = popped.concatinate(n)
                }

                return n
            }
        }
    }
}

extension Tree.Builder where Summary == RopeSummary {
    mutating func push(string s: String) {
        if s.isEmpty {
            return
        }

        if s.utf8.count <= Chunk.maxSize {
            push(leaf: Chunk(s))
        } else {
            var i = s.startIndex
            while i < s.endIndex {
                // TODO: we could pick a better length, e.g. by looking for the next
                // newline.
                var substring = s[i...]
                let n = substring.utf8.count

                let idx: String.Index
                if n > Chunk.maxSize {
                    let minSplit = Chunk.minSize
                    let maxSplit = min(Chunk.maxSize, n - Chunk.minSize)
                    
                    let nl = UInt8(ascii: "\n")
                    let lineBoundary = substring.withUTF8 { buf in
                        buf[minSplit..<maxSplit].firstIndex(of: nl)
                    }
                    
                    let offset = lineBoundary ?? maxSplit
                    let codepoint = substring.utf8.index(substring.startIndex, offsetBy: offset)
                    // TODO: this is SPI. Hopefully it gets exposed soon.
                    idx = substring.unicodeScalars._index(roundingDown: codepoint)
                } else {
                    idx = substring.endIndex
                }

                let prefix = substring[..<idx]
                i = prefix.endIndex
                push(leaf: Chunk(prefix))
            }
        }
    }
}
