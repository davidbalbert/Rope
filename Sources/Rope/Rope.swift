//
//  File.swift
//  
//
//  Created by David Albert on 6/2/23.
//

import Foundation

// a rope made out of a B-tree
// internal nodes are order 8: 4...8 children
// leaf nodes are order 1024: 511..<1024 elements (characters), unless it's root, then 0..<1024

let minChild = 4
let maxChild = 8

let minLeaf = 511
let maxLeaf = 1023

struct Rope {
    var root: Node

    static func + (_ left: Rope, _ right: Rope) -> Rope {
        var b = Builder()
        b.push(left.root)
        b.push(right.root)
        return Rope(b.build())
    }

    init(_ root: Node) {
        self.root = root
    }

    public init() {
        self.init(Node())
    }

    public init(_ string: String) {
        var b = Builder()
        b.push(string: string)
        self.init(b.build())
    }

    public init<S>(_ string: S) where S: Collection, S.Element == Character {
        var b = Builder()
        b.push(string: string)
        self.init(b.build())
    }

    var count: Int {
        return root.count
    }

    mutating func append(_ c: Character) {
        insert(c, at: endIndex)
    }

    mutating func insert(_ c: Character, at i: Index) {
        i.validate(for: root)
        ensureUniqueRoot()

        if let node = root.insert(c, at: i.position) {
            root = node
        }
    }

    // mutating func insert<S>(contentsOf newElements: S, at i: Index) where S: Collection, S.Element == Character {
    //     i.validate(for: root)
    //     ensureUniqueRoot()

    //     if let node = root.insert(contentsOf: newElements, at: i.position) {
    //         root = node
    //     }
    // }

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
    typealias Node = Rope.Node

    static func concat(_ left: Node, _ right: Node) -> Node {
        let h1 = left.height
        let h2 = right.height

        if h1 < h2 {
            if h1 == h2 - 1 && left.atLeastMinSize {
                return mergeChildren([left], right.children)
            }
            
            // TODO: xi has right.children[0].clone(). Is that necessary here?
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
                return mergeLeaves(left, right)
            } else {
                return mergeChildren(left.children, right.children)
            }
        } else {
            if h2 == h1 - 1 && right.atLeastMinSize {
                return mergeChildren(left.children, [right])
            }

            let new = concat(left.children.last!, right)
            if new.height == h1 - 1 {
                return mergeChildren(Array(left.children.dropLast()), [new])
            } else {
                return mergeChildren(Array(left.children.dropLast()), new.children)
            }
        }
    }

    static func mergeLeaves(_ left: Node, _ right: Node) -> Node {
        assert(left.isLeaf && right.isLeaf)

        if left.atLeastMinSize && right.atLeastMinSize {
            return Node([left, right])
        }

        let remainder = left.string.push(possiblySplitting: right.string)
        left.count = left.string.count

        if let remainder {
            return Node([left, Node(remainder)])
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

extension Rope {
    struct Builder {
        // the inner array always has at least one element
        var stack: [[Node]] = []

        mutating func push(_ node: Node) {
            var n = node

            while true {
                if stack.last != nil && stack.last!.last!.height < n.height {
                    n = Node.concat(pop(), n)
                } else if stack.last != nil && stack.last!.last!.height == n.height {
                    if stack.last!.last!.atLeastMinSize && n.atLeastMinSize {
                        stack[stack.count - 1].append(n)
                    } else if n.height == 0 {
                        let newLeaf = stack[stack.count - 1][stack[stack.count - 1].count - 1].string.push(possiblySplitting: n.string)
                        // TODO: find a better place to do this
                        stack[stack.count - 1][stack[stack.count - 1].count - 1].count = stack[stack.count - 1][stack[stack.count - 1].count - 1].string.count
                        if let newLeaf {
                            stack[stack.count - 1].append(Node(newLeaf))
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

        mutating func push(leaf: String) {
            push(Node(leaf))
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
                    n = Node.concat(pop(), n)
                }

                return n
            }
        }

    }
}

extension String {
    mutating func push(possiblySplitting other: String) -> String? {
        self += other

        if count <= maxLeaf {
            return nil
        } else {
            // TODO: split at newline boundary if we can
            let splitPoint = index(startIndex, offsetBy: max(minLeaf, count - maxLeaf))
            let split = String(self[splitPoint...])
            self = String(self[..<splitPoint])
            return split
        }
    }
}
