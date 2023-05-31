enum Value {
    case leaf(String)
    case concat(Node, Node)
}

class Node {
    var height: Int
    var count: Int
    var val: Value

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

    func concat(_ other: Node) -> Node {
        Node(height: max(height, other.height) + 1, count: count + other.count, val: .concat(self, other))
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

extension Node: CustomStringConvertible {
    var description: String {
        switch val {
        case .leaf(let string):
            return string
        case .concat(let left, let right):
            return left.description + right.description
        }
    }
}

public struct Rope {
    var root: Node

    public static func + (lhs: Rope, rhs: Rope) -> Rope {
        Rope(lhs.root.concat(rhs.root))
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

    public subscript(index: Int) -> Character {
        get {
            root[index]
        }
    }

    public var count: Int {
        root.count
    }

    func split(at index: Int) -> (Rope, Rope) {
        let (n1, n2) = root.split(at: index)
        return (Rope(n1), Rope(n2))
    }

    subscript(range: Range<Int>) -> Rope {
        let (_, n) = root.split(at: range.lowerBound)
        let (res, _) = n.split(at: range.upperBound - range.lowerBound)
        return Rope(res)
    }
}

extension Rope: CustomStringConvertible {
    public var description: String {
        root.description
    }
}
