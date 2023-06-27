//
//  Rope.swift
//
//
//  Created by David Albert on 6/21/23.
//

import Foundation

// a rope made out of a B-tree
// internal nodes are order 8: 4...8 children (see Tree.swift)
// leaf nodes are order 1024: 511..<1024 elements (characters), unless it's root, then 0..<1024 (see Chunk.swift)

struct Rope {
    typealias Builder = BTree<Summary>.Builder

    var btree: BTree<Summary>

    init() {
        btree = BTree()
    }
}

extension Rope {
    struct Summary: BTreeSummary {
        var utf16: Int
        var scalars: Int
        var chars: Int
        var newlines: Int
        
        static func += (left: inout Summary, right: Summary) {
            left.utf16 += right.utf16
            left.scalars += right.scalars
            left.chars += right.chars
            left.newlines += right.newlines
        }
        
        static var zero: Summary {
            Summary()
        }
        
        init() {
            self.utf16 = 0
            self.scalars = 0
            self.chars = 0
            self.newlines = 0
        }
        
        init(summarizing chunk: Chunk) {
            self.utf16 = chunk.countUTF16()
            self.scalars = chunk.countScalars()
            self.chars = chunk.countChars()
            self.newlines = chunk.countNewlines()
        }
    }
}

extension Rope: Sequence {
    struct Iterator: IteratorProtocol {
        mutating func next() -> UTF8.CodeUnit? {
            return nil
        }
    }

    func makeIterator() -> Iterator {
        Iterator()
    }
}

extension Rope: BidirectionalCollection {
    struct Index: Comparable {
        var cursor: BTree<Summary>.Cursor

        static func < (left: Rope.Index, right: Rope.Index) -> Bool {
            left.cursor < right.cursor
        }
        
        static func == (left: Rope.Index, right: Rope.Index) -> Bool {
            left.cursor == right.cursor
        }

        func validate(for tree: BTree<Summary>) {
            cursor.validate(for: tree.root)
        }

        mutating func formPredecessor() {
            cursor.formPredecessor()
        }

        mutating func formSuccessor() {
            cursor.formSuccessor()
        }
    }

    var startIndex: Index {
        Index(cursor: BTree.Cursor(startOf: btree))
    }

    var endIndex: Index {
        Index(cursor: BTree.Cursor(endOf: btree))
    }

    func formIndex(before i: inout Index) {
        i.validate(for: btree)
        i.formPredecessor()
    }

    func formIndex(after i: inout Index) {
        i.validate(for: btree)
        i.formSuccessor()
    }

    func index(before i: Index) -> Index {
        var i = i
        formIndex(before: &i)
        return i
    }

    func index(after i: Index) -> Index {
        var i = i
        formIndex(after: &i)
        return i
    }

    subscript(position: Index) -> UTF8.CodeUnit {
        let (chunk, offset) = position.cursor.read(for: btree)!
        return chunk.string.utf8[chunk.string.utf8Index(at: offset)]
    }

    subscript(offset: Int) -> UTF8.CodeUnit {
        let i = Index(cursor: BTree.Cursor(offsetBy: offset, in: btree))
        return self[i]
    }
}


extension Rope: RangeReplaceableCollection {
    mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C: Collection, C.Element == Element {
        subrange.lowerBound.validate(for: btree)
        subrange.upperBound.validate(for: btree)

        var b = Builder()
        b.push(&btree.root, slicedBy: Range(startIndex..<subrange.lowerBound))
        // TODO: fix this once we have metrics
        // b.push(string: newElements)
        b.push(utf8: newElements)
        b.push(&btree.root, slicedBy: Range(subrange.upperBound..<endIndex))
        self.btree = BTree(b.build())
    }

    // The deafult implementation calls append(_:) in a loop. This should be faster.
    mutating func append<S>(contentsOf newElements: S) where S : Sequence, S.Element == Element {
        var b = Builder()
        b.push(&btree.root)
        // TODO: fix this once we have metrics
        b.push(utf8: newElements)
        self.btree = BTree(b.build())
    }

    // override the default behavior
    mutating func reserveCapacity(_ n: Int) {
        // no-op
    }
}

//extension Rope {
//    mutating func append(_ string: String) {
//        append(contentsOf: string)
//    }
//}

extension Rope.Builder {
    mutating func push(string: some Sequence<Character>) {
        var string = String(string)
        string.makeContiguousUTF8()

        var s = string[...]

        while !s.isEmpty {
            let n = s.utf8.count

            if n <= Chunk.maxSize {
                push(leaf: Chunk(s))
                s = s[s.endIndex...]
            } else {
                let i: String.Index
                if n > Chunk.maxSize {
                    let minSplit = Chunk.minSize
                    let maxSplit = Swift.min(Chunk.maxSize, n - Chunk.minSize)

                    let nl = UInt8(ascii: "\n")
                    let lineBoundary = s.withUTF8 { buf in
                        buf[(minSplit-1)..<maxSplit].lastIndex(of: nl)
                    }

                    let offset = lineBoundary ?? maxSplit
                    let codepoint = s.utf8Index(at: offset)
                    // TODO: this is SPI. Hopefully it gets exposed soon.
                    i = s.unicodeScalars._index(roundingDown: codepoint)
                } else {
                    i = s.endIndex
                }

                push(leaf: Chunk(s[..<i]))
                s = s[i...]
            }
        }
    }

    mutating func push(utf8 codeUnits: some Sequence<UTF8.CodeUnit>) {
        push(string: String(bytes: codeUnits, encoding: .utf8)!)
    }
}
