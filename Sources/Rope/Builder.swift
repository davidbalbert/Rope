//
//  Builder.swift
//  
//
//  Created by David Albert on 6/12/23.
//

import Foundation

extension Rope {
    struct Builder {
        // the inner array always has at least one element
        var stack: [[(Node, Bool)]] = []

        mutating func push(_ node: inout Node) {
            var isUnique = isKnownUniquelyReferenced(&node)
            var n = node

            while true {
                if stack.last != nil && stack.last!.last!.0.height < n.height {
                    // TODO: can I destructure instead? I can if `var (popped, isUnique) = pop()` mutates isUnique rather than shadowing it.
                    let t = pop()
                    var popped = t.0
                    isUnique = t.1

                    if !isUnique && popped.isLeaf {
                        popped = popped.clone()
                    }

                    n = popped.concatinate(n)
                    isUnique = true
                } else if stack.last != nil && stack.last!.last!.0.height == n.height {
                    if stack.last!.last!.0.atLeastMinSize && n.atLeastMinSize {
                        stack[stack.count - 1].append((n, isUnique))
                    } else if n.height == 0 {
                        var (lastLeaf, isLeafUnique) = stack[stack.count - 1][stack[stack.count - 1].count - 1]

                        if !isLeafUnique {
                            lastLeaf = lastLeaf.clone()
                            stack[stack.count - 1][stack[stack.count - 1].count - 1] = (lastLeaf, true)
                        }
                        
                        if let newLeaf = lastLeaf.pushLeaf(possiblySplitting: n.string) {
                            assert(newLeaf.atLeastMinSize)
                            stack[stack.count - 1].append((newLeaf, true))
                        }
                    } else {
                        let last = stack[stack.count - 1].removeLast()
                        let c1 = last.0.children
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

                    // TODO: maybe this could be destructuring like above
                    let popped = pop()
                    n = popped.0
                    isUnique = popped.1
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

        mutating func pop() -> (Node, Bool) {
            let nodes = stack.removeLast()
            if nodes.count == 1 {
                return nodes[0]
            } else {
                // TODO: I'm not sure if this is correct.
                return (Node(nodes.map(\.0)), true)
            }
        }

        mutating func build() -> Node {
            if stack.isEmpty {
                return Node()
            } else {
                var n = pop().0
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
