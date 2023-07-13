//
//  RopeTests.swift
//  
//
//  Created by David Albert on 6/2/23.
//

import XCTest
@testable import Rope

final class RopeTests: XCTestCase {
    func testAppendCharacter() {
        var rope = Rope()
        rope.append("a")
        rope.append("b")
        rope.append("c")
        XCTAssertEqual(rope.count, 3)
        XCTAssertEqual("abc", String(rope))
    }

    func testInsertCharacter() {
        var rope = Rope()
        rope.insert("a", at: rope.startIndex)
        rope.insert("b", at: rope.startIndex)
        rope.insert("c", at: rope.startIndex)

        let i = rope.index(after: rope.startIndex)
        rope.insert("z", at: i)

        XCTAssertEqual(rope.count, 4)
        XCTAssertEqual("czba", String(rope))
    }

    func testInitWithString() {
        let rope = Rope("abc")
        XCTAssertEqual(rope.count, 3)
        XCTAssertEqual("abc", String(rope))
    }

    func testInitWithStringBiggerThanALeaf() {
        let string = String(repeating: "a", count: Chunk.maxSize+1)
        let rope = Rope(string)
        XCTAssertEqual(rope.count, Chunk.maxSize+1)
        XCTAssertEqual(string, String(rope))
    }

    func testAdd() {
        let s1 = String(repeating: "a", count: 2000)
        let s2 = String(repeating: "b", count: 2000)
        let rope = Rope(s1) + Rope(s2)
        XCTAssertEqual(4000, rope.count)
        XCTAssertEqual(s1 + s2, String(rope))
    }

    func testAddCopyOnWrite() {
        // Adding two can mutate the rope's underlying nodes. As of this writing,
        // it can specifically mutate the node belonging to the rope on the left
        // of the "+", though this is an implementation detail. We want to make
        // sure we don't mutate the storage of either ropes.
        let r1 = Rope("abc")
        let r2 = Rope("def")

        let r3 = r1 + r2
        XCTAssertEqual(6, r3.count)
        XCTAssertEqual("abcdef", String(r3))

        XCTAssertEqual(3, r1.count)
        XCTAssertEqual("abc", String(r1))

        XCTAssertEqual(3, r2.count)
        XCTAssertEqual("def", String(r2))
    }

    func testSlice() {
        let r = Rope(String(repeating: "a", count: 5000))
        let start = r.index(r.startIndex, offsetBy: 1000)
        let end = r.index(r.startIndex, offsetBy: 2000)

        let slice = r[start..<end]
        XCTAssertEqual(1000, slice.count)
        XCTAssertEqual(String(repeating: "a", count: 1000), String(slice))
    }

    func testSliceHuge() {
        let r = Rope(String(repeating: "a", count: 1_000_000))
        let start = r.index(r.startIndex, offsetBy: 40_000)
        let end = r.index(r.startIndex, offsetBy: 750_000)

        let slice = r[start..<end]
        XCTAssertEqual(710_000, slice.count)
        XCTAssertEqual(String(repeating: "a", count: 710_000), String(slice))
    }

    func testReplaceSubrangeFullRange() {
        var r = Rope("abc")
        r.replaceSubrange(r.startIndex..<r.endIndex, with: "def")
        XCTAssertEqual("def", String(r))
    }

    func testReplaceSubrangePrefix() {
        var r = Rope("Hello, world!")
        r.replaceSubrange(r.startIndex..<r.index(r.startIndex, offsetBy: 5), with: "Goodbye")
        XCTAssertEqual("Goodbye, world!", String(r))
    }

    func testReplaceSubrangeSuffix() {
        var r = Rope("Hello, world!")
        r.replaceSubrange(r.index(r.startIndex, offsetBy: 7)..<r.endIndex, with: "Moon?")
        XCTAssertEqual("Hello, Moon?", String(r))
    }

    func testReplaceSubrangeInternal() {
        var r = Rope("Hello, world!")
        r.replaceSubrange(r.index(r.startIndex, offsetBy: 7)..<r.index(r.endIndex, offsetBy: -1), with: "Earth")
        XCTAssertEqual("Hello, Earth!", String(r))
    }

    func testReplaceSubrangeVeryLong() {
        var r = Rope(String(repeating: "a", count: 1_000_000))
        let start = r.index(r.startIndex, offsetBy: 40_000)
        let end = r.index(r.startIndex, offsetBy: 750_000)

        r.replaceSubrange(start..<end, with: String(repeating: "b", count: 710_000))
        XCTAssertEqual(1_000_000, r.count)
        XCTAssertEqual(String(repeating: "a", count: 40_000) + String(repeating: "b", count: 710_000) + String(repeating: "a", count: 250_000), String(r))
    }

    func testAppendContentsOfInPlace() {
        var r = Rope("abc")
        r.append(contentsOf: "def")
        XCTAssertEqual("abcdef", String(r))
        XCTAssert(isKnownUniquelyReferenced(&r.root))

        #if DEBUG
        XCTAssertEqual(0, r.root.cloneCount)
        #endif
    }

    func testAppendContentsOfCOW() {
        var r1 = Rope("abc")

        XCTAssert(isKnownUniquelyReferenced(&r1.root))

        var r2 = r1

        XCTAssertFalse(isKnownUniquelyReferenced(&r1.root))
        XCTAssertFalse(isKnownUniquelyReferenced(&r2.root))

        r1.append(contentsOf: "def")
        XCTAssertEqual("abcdef", String(r1))
        XCTAssertEqual("abc", String(r2))

        XCTAssert(isKnownUniquelyReferenced(&r1.root))
        XCTAssert(isKnownUniquelyReferenced(&r2.root))

        #if DEBUG
        XCTAssertEqual(1, r1.root.cloneCount)
        #endif
    }

    func testAppendInPlace() {
        var r = Rope("abc")
        r.append("def")
        XCTAssertEqual("abcdef", String(r))
        XCTAssert(isKnownUniquelyReferenced(&r.root))
    }

    func testAppendCOW() {
        var r1 = Rope("abc")

        XCTAssert(isKnownUniquelyReferenced(&r1.root))

        var r2 = r1

        XCTAssertFalse(isKnownUniquelyReferenced(&r1.root))
        XCTAssertFalse(isKnownUniquelyReferenced(&r2.root))

        r1.append("def")
        XCTAssertEqual("abcdef", String(r1))
        XCTAssertEqual("abc", String(r2))

        XCTAssert(isKnownUniquelyReferenced(&r1.root))
        XCTAssert(isKnownUniquelyReferenced(&r2.root))
    }

    func testSummarizeASCII() {
        var r = Rope("foo\nbar\nbaz")

        XCTAssertEqual(11, r.root.count)
        XCTAssertEqual(11, r.root.summary.utf16)
        XCTAssertEqual(11, r.root.summary.scalars)
        XCTAssertEqual(11, r.root.summary.chars)
        XCTAssertEqual(2, r.root.summary.newlines)

        var i = r.index(r.startIndex, offsetBy: 5)
        r.insert(contentsOf: "e", at: i)
        XCTAssertEqual("foo\nbear\nbaz", String(r))

        XCTAssertEqual(12, r.root.count)
        XCTAssertEqual(12, r.root.summary.utf16)
        XCTAssertEqual(12, r.root.summary.scalars)
        XCTAssertEqual(12, r.root.summary.chars)
        XCTAssertEqual(2, r.root.summary.newlines)

        i = r.index(r.startIndex, offsetBy: 3)
        r.remove(at: i)
        XCTAssertEqual("foobear\nbaz", String(r))

        XCTAssertEqual(11, r.root.count)
        XCTAssertEqual(11, r.root.summary.utf16)
        XCTAssertEqual(11, r.root.summary.scalars)
        XCTAssertEqual(11, r.root.summary.chars)
        XCTAssertEqual(1, r.root.summary.newlines)
    }

    func testSummarizeASCIISplit() {
        let s = "foo\n"
        // 1024 == Chunk.maxSize + 1
        assert(1024 % s.utf8.count == 0)

        // 256 == 1024/4 (s is 4 bytes in UTF-8)
        var r = Rope(String(repeating: s, count: 256))
        XCTAssertEqual(1024, r.root.count)
        XCTAssertEqual(1024, r.root.summary.utf16)
        XCTAssertEqual(1024, r.root.summary.scalars)
        XCTAssertEqual(1024, r.root.summary.chars)
        XCTAssertEqual(1024/4, r.root.summary.newlines)

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        // This is somewhat brittle. We're assuming that when the split happens
        // the first child ends up with 511 bytes and the second child ends up
        // with 513. We'll see how long this holds.

        XCTAssertEqual(1024/2 - 1, r.root.children[0].count)
        XCTAssertEqual(1024/2 - 1, r.root.children[0].summary.utf16)
        XCTAssertEqual(1024/2 - 1, r.root.children[0].summary.scalars)
        XCTAssertEqual(1024/2 - 1, r.root.children[0].summary.chars)
        XCTAssertEqual(256/2 - 1, r.root.children[0].summary.newlines)

        XCTAssertEqual(1024/2 + 1, r.root.children[1].count)
        XCTAssertEqual(1024/2 + 1, r.root.children[1].summary.utf16)
        XCTAssertEqual(1024/2 + 1, r.root.children[1].summary.scalars)
        XCTAssertEqual(1024/2 + 1, r.root.children[1].summary.chars)
        XCTAssertEqual(256/2 + 1, r.root.children[1].summary.newlines)

        let i = r.index(r.startIndex, offsetBy: 1024/2 - 1)
        r.insert(contentsOf: "e", at: i)
        XCTAssertEqual(1024 + 1, r.root.count)
        XCTAssertEqual(1024 + 1, r.root.summary.utf16)
        XCTAssertEqual(1024 + 1, r.root.summary.chars)
        XCTAssertEqual(256, r.root.summary.newlines)

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        // children[0] now has one more byte than it used to
        XCTAssertEqual(1024/2 - 1 + 1, r.root.children[0].count)
        XCTAssertEqual(1024/2 - 1 + 1, r.root.children[0].summary.utf16)
        XCTAssertEqual(1024/2 - 1 + 1, r.root.children[0].summary.scalars)
        XCTAssertEqual(1024/2 - 1 + 1, r.root.children[0].summary.chars)
        XCTAssertEqual(256/2 - 1, r.root.children[0].summary.newlines)

        // children[1] remains the same
        XCTAssertEqual(1024/2 + 1, r.root.children[1].count)
        XCTAssertEqual(1024/2 + 1, r.root.children[1].summary.utf16)
        XCTAssertEqual(1024/2 + 1, r.root.children[1].summary.scalars)
        XCTAssertEqual(1024/2 + 1, r.root.children[1].summary.chars)
        XCTAssertEqual(256/2 + 1, r.root.children[1].summary.newlines)
    }

    func testSummarizeASCIIHuge() {
        var r = Rope(String(repeating: "foo\n", count: 200_000))
        XCTAssertEqual(800_000, r.root.count)
        XCTAssertEqual(800_000, r.root.summary.utf16)
        XCTAssertEqual(800_000, r.root.summary.scalars)
        XCTAssertEqual(800_000, r.root.summary.chars)
        XCTAssertEqual(200_000, r.root.summary.newlines)

        let i = r.index(r.startIndex, offsetBy: 400_000)
        r.insert(contentsOf: "e", at: i)
        XCTAssertEqual(String(repeating: "foo\n", count: 100_000) + "e" + String(repeating: "foo\n", count: 100_000), String(r))

        XCTAssertEqual(800_001, r.root.count)
        XCTAssertEqual(800_001, r.root.summary.utf16)
        XCTAssertEqual(800_001, r.root.summary.scalars)
        XCTAssertEqual(800_001, r.root.summary.chars)
        XCTAssertEqual(200_000, r.root.summary.newlines)

        let j = r.index(r.startIndex, offsetBy: 200_000)
        r.insert(contentsOf: "\n", at: j)
        XCTAssertEqual(800_002, r.root.count)
        XCTAssertEqual(800_002, r.root.summary.utf16)
        XCTAssertEqual(800_002, r.root.summary.scalars)
        XCTAssertEqual(800_002, r.root.summary.chars)
        XCTAssertEqual(200_001, r.root.summary.newlines)
    }

    func testSummarizeCombiningCharacters() {
        var r = Rope("foo\u{0301}\nbar\nbaz") // "foó"
        XCTAssertEqual(11, r.count)
        XCTAssertEqual(12, r.unicodeScalars.count)
        XCTAssertEqual(12, r.utf16Count)
        XCTAssertEqual(13, r.utf8.count)
        XCTAssertEqual(3, r.lines.count)

        // this offset is in Characters, not UTF-8 code units or code points.
        // The "a" should be inserted after the "ó".

        let i = r.index(r.startIndex, offsetBy: 3)
        r.insert(contentsOf: "a", at: i)
        XCTAssertEqual("foo\u{0301}a\nbar\nbaz", String(r)) // "foóa"

        XCTAssertEqual(12, r.count)
        XCTAssertEqual(13, r.unicodeScalars.count)
        XCTAssertEqual(13, r.utf16Count)
        XCTAssertEqual(14, r.utf8.count)
        XCTAssertEqual(3, r.lines.count)
    }

    func testSummarizeCombiningCharactersAtChunkBoundary() {
        XCTAssertEqual(1023, Chunk.maxSize)

        var r = Rope(String(repeating: "a", count: 1000))

        XCTAssertEqual(1000, r.count)
        XCTAssertEqual(1000, r.unicodeScalars.count)
        XCTAssertEqual(1000, r.utf16Count)
        XCTAssertEqual(1000, r.utf8.count)

        XCTAssertEqual(0, r.root.height)

        XCTAssertEqual(0, r.root.leaf.prefixCount)
        XCTAssertEqual(1, r.root.leaf.suffixCount)

        // 'combining accute accent' + "b"*999
        r.append("\u{0301}" + String(repeating: "b", count: 999))

        XCTAssertEqual(1, r.root.height)
        XCTAssertEqual(2, r.root.children.count)

        XCTAssertEqual(1000, r.root.children[0].count)
        XCTAssertEqual(1001, r.root.children[1].count) // "´" takes up two bytes

        XCTAssertEqual(0, r.root.children[0].leaf.prefixCount)
        XCTAssertEqual(1, r.root.children[0].leaf.suffixCount)
        XCTAssertEqual(2, r.root.children[1].leaf.prefixCount)
        XCTAssertEqual(1, r.root.children[1].leaf.suffixCount)

        // the last "a" in children[0] combine with the accent at
        // the beginning of children[1] to form a single character.
        XCTAssertEqual(1999, r.count)
        XCTAssertEqual(2000, r.unicodeScalars.count)
        XCTAssertEqual(2000, r.utf16Count)
        XCTAssertEqual(2001, r.utf8.count)

        XCTAssertEqual("a\u{0301}", r[999])
    }

//
//    func testSummarizeCombiningCharactersSplit() {
//        // TODO
//    }
//
//    func testSummarizeCombiningCharactersHuge() {
//        // TODO
//    }
//
//    func testSummarizeOutsideBMP() {
//        // TODO
//    }
//
//    func testSummarizeOutsideBMPSplit() {
//        // TODO
//    }
//
//    func testSummarizeOutsideBMPHuge() {
//        // TODO
//    }
//
//    func testSummarizeMultiCodepointGraphemes() {
//        // TODO
//    }
//
//    func testSummarizeMultiCodepointGraphemesSplit() {
//        // TODO
//    }
//
//    func testSummarizeMultiCodepointGraphemesHuge() {
//        // TODO
//    }


    // Index tests

    func testIndexBeforeAfterASCII() {
        let r = Rope("Hello, world!")

        XCTAssertEqual(0, r.startIndex.position)
        XCTAssertEqual(13, r.endIndex.position)

        let i = r.index(after: r.startIndex)

        XCTAssertEqual(1, i.position)
        XCTAssertEqual(0, r.index(before: i).position)

        let j = r.index(before: r.endIndex)

        XCTAssertEqual(12, j.position)
        XCTAssertEqual(13, r.index(after: j).position)
    }

    func testIndexOffsetByASCII() {
        let r = Rope("Hello, world!")

        let i = r.index(r.startIndex, offsetBy: 3)
        XCTAssertEqual(3, i.position)

        let j = r.index(i, offsetBy: -2)
        XCTAssertEqual(1, j.position)
    }

    func testIndexOffsetByLimitedByASCII() {
        let r = Rope("Hello, world!")

        let i = r.index(r.startIndex, offsetBy: 3, limitedBy: r.endIndex)
        XCTAssertEqual(3, i?.position)

        let j = r.index(r.startIndex, offsetBy: 30, limitedBy: r.endIndex)
        XCTAssertNil(j)
    }

    // Lines
    func testLineIndexing() {
        var r = Rope(String(repeating: "x", count: 1023) + "\n" + String(repeating: "y", count: 1022))

//        XCTAssertEqual(1023*2, r.count)
//        XCTAssertEqual(1, r.root.summary.newlines)
//        XCTAssertEqual(2, r.lines.count) // r.lines.count is one greater than the number of newlines
//        XCTAssertEqual(2, r.root.children.count)
//
//        let startIndex = r.root.children[1].leaf.string.startIndex
//        XCTAssertEqual("\n", r.root.children[1].leaf.string[startIndex])
//
//        XCTAssertEqual(1024, r.index(r.startIndex, offsetBy: 1, using: .newlines).position)
//
//        r = Rope(String(repeating: "x", count: 1022) + "\n" + String(repeating: "y", count: 1023))
//
//        XCTAssertEqual(1023*2, r.count)
//        XCTAssertEqual(1, r.root.summary.newlines)
//        XCTAssertEqual(2, r.lines.count) // r.lines.count is one greater than the number of newlines
//        XCTAssertEqual(2, r.root.children.count)
//
//        let lastIndex = r.root.children[0].leaf.string.index(at: 1022)
//        XCTAssertEqual("\n", r.root.children[0].leaf.string[lastIndex])
//
//        XCTAssertEqual(1023, r.index(r.startIndex, offsetBy: 1, using: .newlines).position)
//
//        XCTAssertEqual(1, r.index(r.startIndex, offsetBy: 1, using: .characters).position)
//
//        r = Rope("abc\ndef")
//        XCTAssertEqual(0, r.root.height)
//        XCTAssertEqual(1, Rope.CharacterMetric().next(0, in: r.root.leaf))
//
//        XCTAssertEqual(1, r.index(r.index(at: 0), offsetBy: 1, using: .characters).position)
//        XCTAssertEqual(0, r.index(r.index(at: 1), offsetBy: -1, using: .characters).position)
//
//
//        XCTAssertEqual(4, Rope.NewlinesMetric().next(0, in: r.root.leaf))
//        XCTAssertEqual(4, r.index(r.startIndex, offsetBy: 1, using: .newlines).position)
//
//        XCTAssertEqual(0, r.index(r.index(at: 4), offsetBy: -1, using: .newlines).position)
        XCTAssertEqual(4, r.index(r.index(at: 7), offsetBy: -1, using: .newlines).position)


        r = Rope("aéc")
        XCTAssertEqual(3, r.count)
        XCTAssertEqual(4, r.utf8.count)

        XCTAssertEqual(1, r.index(r.index(at: 3), offsetBy: -1, using: .characters).position)
        XCTAssertEqual(0, r.index(r.index(at: 2), offsetBy: -1, using: .characters).position)


    }

    // lines tests
    func testShortLines() {
        var r = Rope("foo\nbar\nbaz")

        XCTAssertEqual(3, r.lines.count)
        XCTAssertEqual("foo\n", r.lines[0])
        XCTAssertEqual("bar\n", r.lines[1])
        XCTAssertEqual("baz", r.lines[2])

        XCTAssertEqual(["foo\n", "bar\n", "baz"], Array(r.lines))

        r = Rope("foo\nbar\nbaz\n")

        XCTAssertEqual(4, r.lines.count)
        XCTAssertEqual("foo\n", r.lines[0])
        XCTAssertEqual("bar\n", r.lines[1])
        XCTAssertEqual("baz\n", r.lines[2])
        XCTAssertEqual("", r.lines[3])

        XCTAssertEqual(["foo\n", "bar\n", "baz\n", ""], Array(r.lines))
    }

    func testLongLines() {
        let a = String(repeating: "a", count: 2000) + "\n"
        let b = String(repeating: "b", count: 2000) + "\n"
        let c = String(repeating: "c", count: 2000)

        let r = Rope(a + b + c)

        XCTAssert(r.root.height > 0)

        XCTAssertEqual(3, r.lines.count)
        XCTAssertEqual(a, r.lines[0])
        XCTAssertEqual(b, r.lines[1])
        XCTAssertEqual(c, r.lines[2])

        XCTAssertEqual([a, b, c], Array(r.lines))
    }
}
