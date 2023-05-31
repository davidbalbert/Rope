import XCTest
@testable import Rope

final class RopeTests: XCTestCase {
    func testSimple() {
        let rope = Rope("Hello, world!")
        XCTAssertEqual("Hello, world!", rope.description)
    }

    func testConcat() {
        let rope = Rope("Hello, ") + Rope("world!")
        XCTAssertEqual("Hello, world!", rope.description)
    }

    func testConcatMany() {
        let rope = Rope("a") + Rope("b") + Rope("c") + Rope("d") + Rope("e") + Rope("f") + Rope("g")
        XCTAssertEqual("abcdefg", rope.description)
    }

    func testCount() {
        let rope = Rope("Hello, world!")
        XCTAssertEqual(13, rope.count)
    }

    func testSplit() {
        let rope = Rope("Hello, world!")
        let (left, right) = rope.split(at: 7)
        XCTAssertEqual("Hello, ", left.description)
        XCTAssertEqual("world!", right.description)
    }

    func testConcatAndSplit() {
        let left = Rope("Hello, ")
        let right = Rope("world!")

        let rope = left + right
        let (left2, right2) = rope.split(at: 7)

        XCTAssertEqual("Hello, ", left2.description)
        XCTAssertEqual("world!", right2.description)

        XCTAssertIdentical(left.root, left2.root)
        XCTAssertIdentical(right.root, right2.root)
    }

    func testConcatAndSplitInsideString() {
        let left = Rope("Hello, ")
        let right = Rope("world!")

        let rope = left + right
        let (left2, right2) = rope.split(at: 5)

        XCTAssertEqual("Hello", left2.description)
        XCTAssertEqual(", world!", right2.description)

        XCTAssertNotIdentical(left.root, left2.root)
        XCTAssertNotIdentical(right.root, right2.root)
    }

    func testRangeSliceSimple() {
        let rope = Rope("Hello, world!")
        let slice = rope[7..<13]
        XCTAssertEqual("world!", slice.description)
    }
}
