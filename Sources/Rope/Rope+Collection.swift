//
//  Rope+Collection.swift
//  
//
//  Created by David Albert on 6/12/23.
//

import Foundation

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
        var position: Int
        var path: [PathElement]

        var current: Node // Root if we're at the end of the rope. Otherwise, a leaf.
        var idx: String.Index? // nil if we're at the end of the rope.


        init(startOf rope: Rope) {
            self.root = rope.root
            self.mutationCount = rope.root.mutationCount
            self.position = 0
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
            self.position = rope.count
            self.mutationCount = rope.root.mutationCount
            self.path = []
            self.current = rope.root
            self.idx = nil
        }

        var isAtEnd: Bool {
            return idx == nil
        }

        var value: Character? {
            guard let idx else { return nil }
            return current.string[idx]
        }

        mutating func formSuccessor() {
            guard var idx else {
                preconditionFailure("Cannot advance past endIndex")
            }

            idx = current.string.index(after: idx)

            if idx < current.string.endIndex {
                self.idx = idx
            } else {
                while let el = path.last, el.slot == el.node.children.count - 1 {
                    path.removeLast()
                }

                guard !path.isEmpty else {
                    self.idx = nil
                    self.current = root! // assume root is not nil because Rope.index(after:) called validate(for:)
                    return
                }

                path[path.count - 1].slot += 1
                var node = path[path.count - 1].child

                while !node.isLeaf {
                    path.append(PathElement(node: node, slot: 0))
                    node = node.children[0]
                }

                self.current = node
                self.idx = node.string.startIndex
            }

            self.position += 1
        }

        mutating func formPredecessor() {
            if idx == current.string.startIndex && path.allSatisfy({ $0.slot == 0 }) {
                preconditionFailure("Cannot go below startIndex")
            }

            var i: String.Index
            if let idx {
                i = idx
            } else {
                // we're at endIndex
                var node = current // current == root in this situation
                while !node.isLeaf {
                    path.append(PathElement(node: node, slot: node.children.count - 1))
                    node = node.children[node.children.count - 1]
                }

                current = node
                i = node.string.endIndex
            }

            if i != current.string.startIndex {
                self.idx = current.string.index(before: i)
            } else {
                while let el = path.last, el.slot == 0 {
                    path.removeLast()
                }

                path[path.count - 1].slot -= 1
                var node = path[path.count - 1].child

                while !node.isLeaf {
                    path.append(PathElement(node: node, slot: node.children.count - 1))
                    node = node.children[node.children.count - 1]
                }

                self.current = node
                self.idx = node.string.index(before: node.string.endIndex)
            }

            position -= 1
        }

        func validate(for root: Node) {
            precondition(self.root === root)
            precondition(self.mutationCount == root.mutationCount)
        }

        func validate(_ other: Index) {
            precondition(root === other.root && root != nil)
            precondition(mutationCount == root!.mutationCount)
            precondition(mutationCount == other.mutationCount)
        }
    }
}

extension Rope.Index: Comparable {
    static func < (left: Rope.Index, right: Rope.Index) -> Bool {
        left.validate(right)
        return left.position < right.position
    }

    static func == (lhs: Rope.Index, rhs: Rope.Index) -> Bool {
        lhs.validate(rhs)
        return lhs.position == rhs.position
    }
}

extension Rope: BidirectionalCollection {
    struct Iterator: IteratorProtocol {
        let rope: Rope // retain rope to make sure it doesn't get dealocated during iteration
        var index: Index

        init(rope: Rope) {
            self.rope = rope
            self.index = rope.startIndex
        }

        mutating func next() -> Character? {
            guard let c = index.value else { return nil }
            index.formSuccessor()
            return c
        }
    }

    func makeIterator() -> Iterator {
        Iterator(rope: self)
    }

    var startIndex: Index {
        Index(startOf: self)
    }

    var endIndex: Index {
        Index(endOf: self)
    }

    func index(before i: Index) -> Index {
        i.validate(for: root)
        var i = i
        i.formPredecessor()
        return i
    }

    func index(after i: Index) -> Index {
        i.validate(for: root)
        var i = i
        i.formSuccessor()
        return i
    }

    func formIndex(before i: inout Index) {
        i.validate(for: root)
        i.formPredecessor()
    }

    func formIndex(after i: inout Index) {
        i.validate(for: root)
        i.formSuccessor()
    }

    subscript(index: Index) -> Character {
        index.validate(for: root)
        precondition(!index.isAtEnd, "Index out of bounds")

        return index.value!
    }
}

