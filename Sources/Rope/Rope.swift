//
//  File.swift
//  
//
//  Created by David Albert on 6/2/23.
//

import Foundation

// a rope made out of a B-tree
// internal nodes are order 8: 4...8 children
// leaf nodes are order 1024: 511..<1024 characters (elements), unless it's root, then 0..<1024

let internalOrder = 8
let leafOrder = 1024

struct Rope {
    var root: Node

    init(_ root: Node) {
        self.root = root
    }

    init() {
        self.init(Node())
    }

    var count: Int {
        return root.count
    }

    mutating func append(_ c: Character) {
        ensureUniqueRoot()

        if let node = root.append(c) {
            root = node
        }
    }

    mutating func ensureUniqueRoot() {
        if !isKnownUniquelyReferenced(&root) {
            root = root.clone()
        }
    }
}

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
    }
}

extension Rope.Node {
    convenience init(_ height: Int, _ children: [Rope.Node]) {
        precondition(internalOrder/2 <= children.count && children.count <= internalOrder)
        let count = children.reduce(0) { $0 + $1.count }
        self.init(height, count, children, "")
    }

    convenience init(_ string: String) {
        precondition(string.count < leafOrder)
        self.init(0, string.count, [], string)
    }

    convenience init() {
        self.init("")
    }

    var isLeaf: Bool {
        return height == 0
    }

    func append(_ c: Character) -> Rope.Node? {
        mutationCount &+= 1

        if isLeaf {
            if count < leafOrder {
                string.append(c)
                count += 1
                return nil
            } else {
                let mid = string.index(string.startIndex, offsetBy: leafOrder / 2)
                let left = Rope.Node(String(string[..<mid]))
                let right = Rope.Node(String(string[mid...]))
                let node = Rope.Node(1, count, [left, right], "")
                return node.append(c) ?? node
            }
        } else {
            if count < internalOrder {
                ensureUniqueChild(at: count - 1)
                if let node = children[count - 1].append(c) {
                    children[count - 1] = node
                }

                count += 1
                return nil
            } else {
                let mid = internalOrder / 2
                let left = Rope.Node(height, Array(children[..<mid]))
                let right = Rope.Node(height, Array(children[mid...]))
                let node = Rope.Node(height + 1, count, [left, right], "")
                return node.append(c) ?? node
            }
        }
    }

    func ensureUniqueChild(at index: Int) {
        if !isKnownUniquelyReferenced(&children[index]) {
            children[index] = children[index].clone()
        }
    }

    func clone() -> Rope.Node {
        if isLeaf {
            return Rope.Node(string)
        } else {
            return Rope.Node(height, count, children, "")
        }
    }
}

extension Rope {
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
        var path: [PathElement]

        var current: Node // Always a leaf. Only valid if offset is present.
        var idx: String.Index? // nil if we're at the end of the rope

        init(startOf rope: Rope) {
            self.root = rope.root
            self.mutationCount = rope.root.mutationCount
            self.path = []

            var node = rope.root
            while !node.isLeaf {
                path.append(PathElement(node: node, slot: 0))
                node = node.children[0]
            }

            self.current = node
            self.idx = node.string.startIndex
        }
        
        init(endOf rope: Rope) {
            self.root = rope.root
            self.mutationCount = rope.root.mutationCount
            self.path = []
            self.current = rope.root
            self.idx = nil
        }

        mutating func formSuccessor() {
            guard let idx else {
                preconditionFailure("Cannot advance past endIndex")
            }

            if idx < current.string.endIndex {
                self.idx = current.string.index(after: idx)
            } else {
                while let el = path.last, el.slot == el.node.children.count - 1 {
                    path.removeLast()
                }

                guard !path.isEmpty else {
                    self.idx = nil
                    return
                }

                path[path.count - 1].slot += 1
                var node = path[path.count - 1].child

                while !node.isLeaf {
                    path.append(PathElement(node: node, slot: 0))
                    node = node.children[0]
                }

                self.current = node
            }
        }

        func validate(for rope: Rope) {
            precondition(root === rope.root)
            precondition(mutationCount == rope.root.mutationCount)
        }

        static func validate(_ left: Index, _ right: Index) {
            precondition(left.root === right.root && left.root != nil)
            precondition(left.mutationCount == left.root!.mutationCount)
            precondition(left.mutationCount == right.mutationCount)
        }
    }
}