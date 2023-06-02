enum Value {
    case leaf(String)
    case concat(Node, Node)
}

class Node {
    var height: Int
    var count: Int
    var val: Value

    static func + (lhs: Node, rhs: Node) -> Node {
        lhs.concat(rhs)
    }

    init(height: Int, count: Int, val: Value) {
        self.height = height
        self.count = count
        self.val = val
    }

    convenience init(_ string: String) {
        self.init(height: 0, count: string.count, val: .leaf(string))
    }

    convenience init<S: StringProtocol>(_ string: S) {
        self.init(height: 0, count: string.count, val: .leaf(String(string)))
    }

    convenience init(_ character: Character) {
        self.init(String(character))
    }

    func concat(_ other: Node) -> Node {
        if count == 0 {
            return other
        } else if other.count == 0 {
            return self
        } else {
            return Node(height: Swift.max(height, other.height) + 1, count: count + other.count, val: .concat(self, other))
        }
    }

    // returns two nodes, with ranges 0..<index and index..<count
    // index is in the range 0...count
    func split(at index: Int) -> (Node, Node) {
        assert((0...count).contains(index))

        switch val {
            case .leaf(let string):
                if index == 0 {
                    return (Node(""), self)
                } else if index == count {
                    return (self, Node(""))
                } else {
                    let i = string.index(string.startIndex, offsetBy: index)

                    let left = string[..<i]
                    let right = string[i...]
                    return (Node(left), Node(right))
                }
            case .concat(let left, let right):
                if index == left.count {
                    return (left, right)
                } else if index < left.count {
                    let (l1, l2) = left.split(at: index)
                    return (l1, l2.concat(right))
                } else {
                    let (r1, r2) = right.split(at: index - left.count)
                    return (left.concat(r1), r2)
                }
        }
    }
}

extension Node: Sequence {
    typealias Element = Character

    struct Iterator: IteratorProtocol {
        var root: Node
        var position: Int
        var stack: [(Node, Int)] // (node, childNumber)

        var _leaf: String?
        var leaf: String {
            get {
                _leaf!
            }
            set {
                _leaf = newValue
            }
        }

        var _offset: String.Index?
        var offset: String.Index {
            get {
                _offset!
            }
            set {
                _offset = newValue
            }
        }

        init(_ root: Node, position: Int = 0) {
            if position < 0 || position > root.count {
                fatalError("position out of range")
            }

            self.root = root
            self.position = position
            stack = []

            // Technically, iterators are supposed to be created in O(1) time, and this
            // is O(log n), but I'm going to ignore that for now.
            var node = root
            var pos = position
            while true {
                switch node.val {
                case .leaf(let string):
                    self.leaf = string
                    self.offset = string.index(string.startIndex, offsetBy: pos)
                    return
                case .concat(let left, let right):
                    if pos < left.count {
                        stack.append((node, 0))
                        node = left
                    } else {
                        stack.append((node, 1))
                        pos -= left.count
                        node = right
                    }
                }
            }
        }

        mutating func next() -> Character? {
            if position == root.count {
                return nil
            }

            if offset == leaf.endIndex {
                // go up until we get to a node where we haven't traversed the right child
                var node: Node?
                while !stack.isEmpty {
                    let (n, childNumber) = stack.removeLast()
                    if childNumber == 0 {
                        node = n
                        break
                    }
                }

                // move to the right child of that node
                guard var node = node, case let .concat(_, n) = node.val else {
                    fatalError("shouldn't happen")
                }

                node = n

                // go down the left side of that node
                done: while true {
                    switch node.val {
                    case .leaf(let string):
                        leaf = string
                        offset = string.startIndex
                        break done
                    case .concat(let left, _):
                        stack.append((node, 1))
                        node = left
                    }
                }
            }

            let result = leaf[offset]
            offset = leaf.index(after: offset)
            position += 1

            return result
        }
    }

    func makeIterator() -> Iterator {
        Iterator(self)
    }
}

extension Node: Collection {
    var startIndex: Int {
        0
    }

    var endIndex: Int {
        count
    }

    func index(after i: Int) -> Int {
        i + 1
    }

    subscript(index: Int) -> Character {
        assert((0..<count).contains(index))

        switch val {
        case .leaf(let string):
            return string[string.index(string.startIndex, offsetBy: index)]
        case .concat(let left, let right):
            if index < left.count {
                return left[index]
            } else {
                return right[index - left.count]
            }
        }
    }

    public subscript(range: Range<Int>) -> SimpleRope {
        assert(range.lowerBound >= 0 && range.upperBound <= count)

        let (_, n) = split(at: range.lowerBound)
        let (res, _) = n.split(at: range.upperBound - range.lowerBound)
        return SimpleRope(res)
    }
}

public struct SimpleRope {
    var root: Node

    public static func + (lhs: SimpleRope, rhs: SimpleRope) -> SimpleRope {
        SimpleRope(lhs.root.concat(rhs.root))
    }

    init(_ string: String) {
        root = Node(string)
    }

    init<S: StringProtocol>(_ string: S) {
        root = Node(string)
    }

    internal init(_ node: Node) {
        root = node
    }

    public var count: Int {
        root.count
    }

    func split(at index: Int) -> (SimpleRope, SimpleRope) {
        let (n1, n2) = root.split(at: index)
        return (SimpleRope(n1), SimpleRope(n2))
    }

    mutating func insert(_ newElement: Character, at i: Int) {
        let (n1, n2) = root.split(at: i)
        root = n1 + Node(newElement) + n2
    }

    mutating func insert<S>(contentsOf newElements: S, at i: Int) where S : Collection, S.Element == Character {
        let (n1, n2) = root.split(at: i)
        root = n1 + Node(String(newElements)) + n2
    }

    mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C : Collection, C.Element == Character {
        let (n1, n2) = root.split(at: subrange.lowerBound)
        let (_, n3) = n2.split(at: subrange.upperBound - subrange.lowerBound)
        root = n1 + Node(String(newElements)) + n3
    }

    mutating func removeSubrange(_ subrange: Range<Int>) {
        let (n1, _) = root.split(at: subrange.lowerBound)
        let (_, n2) = root.split(at: subrange.upperBound)
        root = n1 + n2
    }
}

extension SimpleRope: Sequence {
    public func makeIterator() -> some IteratorProtocol<Character> {
        root.makeIterator()
    }
}

extension SimpleRope: Collection {
    public var startIndex: Int {
        root.startIndex
    }

    public var endIndex: Int {
        root.endIndex
    }

    public func index(after i: Int) -> Int {
        if i < 0 || i >= count {
            fatalError("index out of bounds")
        }

        return i + 1
    }

    public subscript(index: Int) -> Character {
        root[index]
    }

    public subscript(range: Range<Int>) -> SimpleRope {
        root[range]
    }
}

extension SimpleRope: CustomStringConvertible {
    public var description: String {
        String(self)
    }
}
