//
//  RopeTests.swift
//  
//
//  Created by David Albert on 6/2/23.
//

import XCTest
@testable import Rope

final class RopeTests: XCTestCase {
    func testHmm() {
        var r = Rope()
        r.append(contentsOf: [97, 98, 99])
        XCTAssertEqual(97, r[0])
        XCTAssertEqual(98, r[1])
        XCTAssertEqual(99, r[2])
    }

//    func testAppendCharacter() {
//        var rope = Rope()
//        rope.append("a")
//        rope.append("b")
//        rope.append("c")
//        XCTAssertEqual(rope.count, 3)
//        XCTAssertEqual("abc", String(rope))
//    }
//
//    func testInsertCharacter() {
//        var rope = Rope()
//        rope.insert("a", at: rope.startIndex)
//        rope.insert("b", at: rope.startIndex)
//        rope.insert("c", at: rope.startIndex)
//
//        let i = rope.index(after: rope.startIndex)
//        rope.insert("z", at: i)
//
//        XCTAssertEqual(rope.count, 4)
//        XCTAssertEqual("czba", String(rope))
//    }
//
//    func testInitWithString() {
//        let rope = Rope("abc")
//        XCTAssertEqual(rope.count, 3)
//        XCTAssertEqual("abc", String(rope))
//    }
//
//    func testInitWithStringBiggerThanALeaf() {
//        let string = String(repeating: "a", count: Chunk.maxSize+1)
//        let rope = Rope(string)
//        XCTAssertEqual(rope.count, Chunk.maxSize+1)
//        XCTAssertEqual(string, String(rope))
//    }
//
//    func testAdd() {
//        let s1 = String(repeating: "a", count: 2000)
//        let s2 = String(repeating: "b", count: 2000)
//        let rope = Rope(s1) + Rope(s2)
//        XCTAssertEqual(4000, rope.count)
//        XCTAssertEqual(s1 + s2, String(rope))
//    }
//
//    func testAddCopyOnWrite() {
//        // Adding two can mutate the rope's underlying nodes. As of this writing,
//        // it can specifically mutate the node belonging to the rope on the left
//        // of the "+", though this is an implementation detail. We want to make
//        // sure we don't mutate the storage of either ropes.
//        let r1 = Rope("abc")
//        let r2 = Rope("def")
//
//        let r3 = r1 + r2
//        XCTAssertEqual(6, r3.count)
//        XCTAssertEqual("abcdef", String(r3))
//
//        XCTAssertEqual(3, r1.count)
//        XCTAssertEqual("abc", String(r1))
//
//        XCTAssertEqual(3, r2.count)
//        XCTAssertEqual("def", String(r2))
//    }
//
//    func testSlice() {
//        let r = Rope(String(repeating: "a", count: 5000))
//        let start = r.index(r.startIndex, offsetBy: 1000)
//        let end = r.index(r.startIndex, offsetBy: 2000)
//
//        let slice = r[start..<end]
//        XCTAssertEqual(1000, slice.count)
//        XCTAssertEqual(String(repeating: "a", count: 1000), String(slice))
//    }
//
//    func testSliceHuge() {
//        let r = Rope(String(repeating: "a", count: 1_000_000))
//        let start = r.index(r.startIndex, offsetBy: 40_000)
//        let end = r.index(r.startIndex, offsetBy: 750_000)
//
//        let slice = r[start..<end]
//        XCTAssertEqual(710_000, slice.count)
//        XCTAssertEqual(String(repeating: "a", count: 710_000), String(slice))
//    }
//
//    func testReplaceSubrangeFullRange() {
//        var r = Rope("abc")
//        r.replaceSubrange(r.startIndex..<r.endIndex, with: "def")
//        XCTAssertEqual("def", String(r))
//    }
//
//    func testReplaceSubrangePrefix() {
//        var r = Rope("Hello, world!")
//        r.replaceSubrange(r.startIndex..<r.index(r.startIndex, offsetBy: 5), with: "Goodbye")
//        XCTAssertEqual("Goodbye, world!", String(r))
//    }
//
//    func testReplaceSubrangeSuffix() {
//        var r = Rope("Hello, world!")
//        r.replaceSubrange(r.index(r.startIndex, offsetBy: 7)..<r.endIndex, with: "Moon?")
//        XCTAssertEqual("Hello, Moon?", String(r))
//    }
//
//    func testReplaceSubrangeInternal() {
//        var r = Rope("Hello, world!")
//        r.replaceSubrange(r.index(r.startIndex, offsetBy: 7)..<r.index(r.endIndex, offsetBy: -1), with: "Earth")
//        XCTAssertEqual("Hello, Earth!", String(r))
//    }
//
//    func testReplaceSubrangeVeryLong() {
//        var r = Rope(String(repeating: "a", count: 1_000_000))
//        let start = r.index(r.startIndex, offsetBy: 40_000)
//        let end = r.index(r.startIndex, offsetBy: 750_000)
//
//        r.replaceSubrange(start..<end, with: String(repeating: "b", count: 710_000))
//        XCTAssertEqual(1_000_000, r.count)
//        XCTAssertEqual(String(repeating: "a", count: 40_000) + String(repeating: "b", count: 710_000) + String(repeating: "a", count: 250_000), String(r))
//    }
//
//    func testAppendContentsOfInPlace() {
//        var r = Rope("abc")
//        r.append(contentsOf: "def")
//        XCTAssertEqual("abcdef", String(r))
//        XCTAssert(isKnownUniquelyReferenced(&r.root))
//        XCTAssertEqual(0, r.root.cloneCount)
//    }
//
//    func testAppendContentsOfCOW() {
//        var r1 = Rope("abc")
//
//        XCTAssert(isKnownUniquelyReferenced(&r1.root))
//
//        var r2 = r1
//
//        XCTAssertFalse(isKnownUniquelyReferenced(&r1.root))
//        XCTAssertFalse(isKnownUniquelyReferenced(&r2.root))
//
//        r1.append(contentsOf: "def")
//        XCTAssertEqual("abcdef", String(r1))
//        XCTAssertEqual("abc", String(r2))
//
//        XCTAssert(isKnownUniquelyReferenced(&r1.root))
//        XCTAssert(isKnownUniquelyReferenced(&r2.root))
//        XCTAssertEqual(1, r1.root.cloneCount)
//    }
//
//    func testAppendInPlace() {
//        var r = Rope("abc")
//        r.append("def")
//        XCTAssertEqual("abcdef", String(r))
//        XCTAssert(isKnownUniquelyReferenced(&r.root))
//    }
//
//    func testAppendCOW() {
//        var r1 = Rope("abc")
//
//        XCTAssert(isKnownUniquelyReferenced(&r1.root))
//
//        var r2 = r1
//
//        XCTAssertFalse(isKnownUniquelyReferenced(&r1.root))
//        XCTAssertFalse(isKnownUniquelyReferenced(&r2.root))
//
//        r1.append("def")
//        XCTAssertEqual("abcdef", String(r1))
//        XCTAssertEqual("abc", String(r2))
//
//        XCTAssert(isKnownUniquelyReferenced(&r1.root))
//        XCTAssert(isKnownUniquelyReferenced(&r2.root))
//    }
//
//    func testSummarizeASCII() {
//        var r = Rope("foo\nbar\nbaz")
//
//        XCTAssertEqual(11, r.root.count)
//        XCTAssertEqual(11, r.root.summary.utf16)
//        XCTAssertEqual(11, r.root.summary.scalars)
//        XCTAssertEqual(11, r.root.summary.chars)
//        XCTAssertEqual(2, r.root.summary.newlines)
//
//        var i = r.index(r.startIndex, offsetBy: 5)
//        r.insert(contentsOf: "e", at: i)
//        XCTAssertEqual("foo\nbear\nbaz", String(r))
//
//        XCTAssertEqual(12, r.root.count)
//        XCTAssertEqual(12, r.root.summary.utf16)
//        XCTAssertEqual(12, r.root.summary.scalars)
//        XCTAssertEqual(12, r.root.summary.chars)
//        XCTAssertEqual(2, r.root.summary.newlines)
//
//        i = r.index(r.startIndex, offsetBy: 3)
//        r.remove(at: i)
//        XCTAssertEqual("foobear\nbaz", String(r))
//
//        XCTAssertEqual(11, r.root.count)
//        XCTAssertEqual(11, r.root.summary.utf16)
//        XCTAssertEqual(11, r.root.summary.scalars)
//        XCTAssertEqual(11, r.root.summary.chars)
//        XCTAssertEqual(1, r.root.summary.newlines)
//    }
//
//    func testSummarizeASCIISplit() {
//        let s = "foo\n"
//        let nbytes = Chunk.maxSize + 1
//        assert(nbytes % s.utf8.count == 0)
//
//        let n = nbytes / s.utf8.count
//
//        var r = Rope(String(repeating: s, count: n))
//        XCTAssertEqual(nbytes, r.root.count)
//        XCTAssertEqual(nbytes, r.root.summary.utf16)
//        XCTAssertEqual(nbytes, r.root.summary.scalars)
//        XCTAssertEqual(nbytes, r.root.summary.chars)
//        XCTAssertEqual(n, r.root.summary.newlines)
//
//        XCTAssertEqual(1, r.root.height)
//        XCTAssertEqual(2, r.root.children.count)
//
//        let c1bytes = nbytes/2 - 1 // Brittle. We'll see if this holds forever.
//        let c2bytes = nbytes/2 + 1
//
//        let c1lines = n/2 - 1
//        let c2lines = n/2 + 1
//
//        XCTAssertEqual(c1bytes, r.root.children[0].count)
//        XCTAssertEqual(c1bytes, r.root.children[0].summary.utf16)
//        XCTAssertEqual(c1bytes, r.root.children[0].summary.scalars)
//        XCTAssertEqual(c1bytes, r.root.children[0].summary.chars)
//        XCTAssertEqual(c1lines, r.root.children[0].summary.newlines)
//
//        XCTAssertEqual(c2bytes, r.root.children[1].count)
//        XCTAssertEqual(c2bytes, r.root.children[1].summary.utf16)
//        XCTAssertEqual(c2bytes, r.root.children[1].summary.scalars)
//        XCTAssertEqual(c2bytes, r.root.children[1].summary.chars)
//        XCTAssertEqual(c2lines, r.root.children[1].summary.newlines)
//
//        let i = r.index(r.startIndex, offsetBy: c1bytes)
//        r.insert(contentsOf: "e", at: i)
//        XCTAssertEqual(nbytes + 1, r.root.count)
//        XCTAssertEqual(nbytes + 1, r.root.summary.utf16)
//        XCTAssertEqual(nbytes + 1, r.root.summary.chars)
//        XCTAssertEqual(n, r.root.summary.newlines)
//
//        XCTAssertEqual(1, r.root.height)
//        XCTAssertEqual(2, r.root.children.count)
//
//        XCTAssertEqual(c1bytes + 1, r.root.children[0].count)
//        XCTAssertEqual(c1bytes + 1, r.root.children[0].summary.utf16)
//        XCTAssertEqual(c1bytes + 1, r.root.children[0].summary.scalars)
//        XCTAssertEqual(c1bytes + 1, r.root.children[0].summary.chars)
//        XCTAssertEqual(c1lines, r.root.children[0].summary.newlines)
//
//        XCTAssertEqual(c2bytes, r.root.children[1].count)
//        XCTAssertEqual(c2bytes, r.root.children[1].summary.utf16)
//        XCTAssertEqual(c2bytes, r.root.children[1].summary.scalars)
//        XCTAssertEqual(c2bytes, r.root.children[1].summary.chars)
//        XCTAssertEqual(c2lines, r.root.children[1].summary.newlines)
//    }
//
//    func testSummarizeASCIIHuge() {
//        var r = Rope(String(repeating: "foo\n", count: 200_000))
//        XCTAssertEqual(800_000, r.root.count)
//        XCTAssertEqual(800_000, r.root.summary.utf16)
//        XCTAssertEqual(800_000, r.root.summary.scalars)
//        XCTAssertEqual(800_000, r.root.summary.chars)
//        XCTAssertEqual(200_000, r.root.summary.newlines)
//
//        let i = r.index(r.startIndex, offsetBy: 400_000)
//        r.insert(contentsOf: "e", at: i)
//        XCTAssertEqual(String(repeating: "foo\n", count: 100_000) + "e" + String(repeating: "foo\n", count: 100_000), String(r))
//
//        XCTAssertEqual(800_001, r.root.count)
//        XCTAssertEqual(800_001, r.root.summary.utf16)
//        XCTAssertEqual(800_001, r.root.summary.scalars)
//        XCTAssertEqual(800_001, r.root.summary.chars)
//        XCTAssertEqual(200_000, r.root.summary.newlines)
//
//        let j = r.index(r.startIndex, offsetBy: 200_000)
//        r.insert(contentsOf: "\n", at: j)
//        XCTAssertEqual(800_002, r.root.count)
//        XCTAssertEqual(800_002, r.root.summary.utf16)
//        XCTAssertEqual(800_002, r.root.summary.scalars)
//        XCTAssertEqual(800_002, r.root.summary.chars)
//        XCTAssertEqual(200_001, r.root.summary.newlines)
//    }
//
//    func testSummarizeCombiningCharacters() {
//        var r = Rope("foo\u{0301}\nbar\nbaz") // "foó"
//        XCTAssertEqual(13, r.root.count)
//        XCTAssertEqual(12, r.root.summary.utf16)
//        XCTAssertEqual(12, r.root.summary.scalars)
//        XCTAssertEqual(11, r.root.summary.chars)
//        XCTAssertEqual(2, r.root.summary.newlines)
//
//        // this offset is in Characters, not UTF-8 code units or code points.
//        // The "a" should be inserted after the "é".
//
//        // Not currently working
//
//        // let i = r.index(r.startIndex, offsetBy: 3)
//        // r.insert(contentsOf: "a", at: i)
//        // XCTAssertEqual("fooa\u{0301}\nbar\nbaz", String(r))
//        //
//        // XCTAssertEqual(14, r.root.count)
//        // XCTAssertEqual(13, r.root.summary.utf16)
//        // XCTAssertEqual(13, r.root.summary.scalars)
//        // XCTAssertEqual(12, r.root.summary.chars)
//        // XCTAssertEqual(2, r.root.summary.newlines)
//    }
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
}
