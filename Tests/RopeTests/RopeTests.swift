import XCTest
@testable import Rope

final class RopeTests: XCTestCase {
    func testSimple() {
        let rope = Rope("Hello, world!")
        XCTAssertEqual("Hello, world!", rope.description)
        XCTAssertEqual(13, rope.count)
    }

    func testConcat() {
        let rope = Rope("Hello, ") + Rope("world!")
        XCTAssertEqual("Hello, world!", rope.description)
        XCTAssertEqual(13, rope.count)
    }

    func testConcatMany() {
        let rope = Rope("a") + Rope("b") + Rope("c") + Rope("d") + Rope("e") + Rope("f") + Rope("g")
        XCTAssertEqual("abcdefg", rope.description)
        XCTAssertEqual(7, rope.count)
    }

    func testSplit() {
        let rope = Rope("Hello, world!")
        let (left, right) = rope.split(at: 7)

        XCTAssertEqual("Hello, ", left.description)
        XCTAssertEqual(7, left.count)

        XCTAssertEqual("world!", right.description)
        XCTAssertEqual(6, right.count)
    }

    func testConcatAndSplit() {
        let left = Rope("Hello, ")
        let right = Rope("world!")

        let rope = left + right
        let (left2, right2) = rope.split(at: 7)

        XCTAssertEqual("Hello, ", left2.description)
        XCTAssertEqual(7, left2.count)

        XCTAssertEqual("world!", right2.description)
        XCTAssertEqual(6, right2.count)

        XCTAssertIdentical(left.root, left2.root)
        XCTAssertIdentical(right.root, right2.root)
    }

    func testConcatAndSplitInsideString() {
        let left = Rope("Hello, ")
        let right = Rope("world!")

        let rope = left + right
        let (left2, right2) = rope.split(at: 5)

        XCTAssertEqual("Hello", left2.description)
        XCTAssertEqual(5, left2.count)

        XCTAssertEqual(", world!", right2.description)
        XCTAssertEqual(8, right2.count)

        XCTAssertNotIdentical(left.root, left2.root)
        XCTAssertNotIdentical(right.root, right2.root)
    }

    func testRangeSliceSimple() {
        let rope = Rope("Hello, world!")
        var slice = rope[7..<13]
        XCTAssertEqual("world!", slice.description)
        XCTAssertEqual(6, slice.count)

        slice = rope[0..<13]
        XCTAssertEqual("Hello, world!", slice.description)
        XCTAssertEqual(13, slice.count)
        XCTAssertIdentical(rope.root, slice.root)

        slice = rope[0..<5]
        XCTAssertEqual("Hello", slice.description)
        XCTAssertEqual(5, slice.count)

        slice = rope[1..<11]
        XCTAssertEqual("ello, worl", slice.description)
        XCTAssertEqual(10, slice.count)
    }

    func testRangeSliceSplitOnBoundary() {
        let left = Rope("Hello, ")
        let right = Rope("world!")

        let rope = left + right
        var slice = rope[7..<13]
        XCTAssertEqual("world!", slice.description)
        XCTAssertEqual(6, slice.count)
        XCTAssertIdentical(right.root, slice.root)

        slice = rope[0..<7]
        XCTAssertEqual("Hello, ", slice.description)
        XCTAssertEqual(7, slice.count)
        XCTAssertIdentical(left.root, slice.root)

        slice = rope[0..<5]
        XCTAssertEqual("Hello", slice.description)
        XCTAssertEqual(5, slice.count)
        XCTAssertNotIdentical(left.root, slice.root)
    }
}
