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

    func testConcat() {
        let s1 = String(repeating: "a", count: 2000)
        let s2 = String(repeating: "b", count: 2000)
        let rope = Rope(s1) + Rope(s2)
        XCTAssertEqual(rope.count, 4000)
        XCTAssertEqual(s1 + s2, String(rope))
    }
}
