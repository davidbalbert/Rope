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
        let string = String(repeating: "a", count: maxLeaf+1)
        let rope = Rope(string)
        XCTAssertEqual(rope.count, maxLeaf+1)
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
}
