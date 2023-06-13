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
        var stack: [[Node]] = []

        mutating func push(_ node: Node) {
            var n = node

            while true {
                if stack.last != nil && stack.last!.last!.height < n.height {
                    var popped = pop()
                    if !isKnownUniquelyReferenced(&popped) && popped.isLeaf {
                        popped = popped.clone()
                    }

                    n = popped.concatinate(n)
                } else if stack.last != nil && stack.last!.last!.height == n.height {
                    if stack.last!.last!.atLeastMinSize && n.atLeastMinSize {
                        stack[stack.count - 1].append(n)
                    } else if n.height == 0 {
                        let newLeaf = { (lastLeaf: inout Node) -> Node? in
                            if !isKnownUniquelyReferenced(&lastLeaf) {
                                lastLeaf = lastLeaf.clone()
                            }

                            return lastLeaf.pushLeaf(possiblySplitting: n.string)
                        }(&stack[stack.count - 1][stack[stack.count - 1].count - 1])

                        if let newLeaf {
                            stack[stack.count - 1].append(newLeaf)
                        }
                    } else {
                        let last = stack[stack.count - 1].removeLast()
                        let c1 = last.children
                        let c2 = n.children
                        let count = c1.count + c2.count
                        if count <= maxChild {
                            stack[stack.count - 1].append(Node(c1 + c2))
                        } else {
                            let split = count / 2
                            let children = [c1, c2].joined()
                            stack[stack.count - 1].append(Node(children.prefix(split)))
                            stack[stack.count - 1].append(Node(children.dropFirst(split)))
                        }
                    }

                    if stack[stack.count - 1].count < maxChild {
                        break
                    }

                    n = pop()
                } else {
                    stack.append([n])
                    break
                }
            }
        }

        mutating func push(_ node: Node, slicedBy range: Range<Int>) {
            if range.isEmpty {
                return
            }

            if range == 0..<node.count {
                push(node)
                return
            }

            if node.isLeaf {
                push(leaf: node.string, slicedBy: range)
            } else {
                var offset = 0
                for child in node.children {
                    if range.upperBound <= offset {
                        break
                    }

                    let childRange = 0..<child.count
                    let intersection = childRange.clamped(to: range.offset(by: -offset))
                    push(child, slicedBy: intersection)
                    offset += child.count
                }
            }

        }

        mutating func push(leaf: String) {
            push(Node(leaf))
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

        mutating func push<S>(string s: S) where S: Collection, S.Element == Character {
            push(string: String(s))
        }

        mutating func pop() -> Node {
            let nodes = stack.removeLast()
            if nodes.count == 1 {
                return nodes[0]
            } else {
                return Node(nodes)
            }
        }

        mutating func build() -> Node {
            if stack.isEmpty {
                return Node()
            } else {
                var n = pop()
                while !stack.isEmpty {
                    var popped = pop()
                    if !isKnownUniquelyReferenced(&popped) && popped.isLeaf {
                        popped = popped.clone()
                    }

                    n = popped.concatinate(n)
                }

                return n
            }
        }
    }
}
