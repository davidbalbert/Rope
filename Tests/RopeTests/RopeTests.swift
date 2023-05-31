import XCTest
@testable import Rope

final class RopeTests: XCTestCase {
    func testSimple() {
        let rope = Rope("Hello, world!")
        XCTAssertEqual("Hello, world!", String(rope))
        XCTAssertEqual(13, rope.count)
    }

    func testConcat() {
        let rope = Rope("Hello, ") + Rope("world!")
        XCTAssertEqual("Hello, world!", String(rope))
        XCTAssertEqual(13, rope.count)
    }

    func testConcatMany() {
        let rope = Rope("a") + Rope("b") + Rope("c") + Rope("d") + Rope("e") + Rope("f") + Rope("g")
        XCTAssertEqual("abcdefg", String(rope))
        XCTAssertEqual(7, rope.count)
    }

    func testConcatEmptyLeft() {
        let left = Rope("")
        let right = Rope("Hello, world!")
        let rope = left + right
        XCTAssertEqual("Hello, world!", String(rope))
        XCTAssertEqual(13, rope.count)
        XCTAssertEqual(0, rope.root.height)
        XCTAssertIdentical(right.root, rope.root)
    }

    func testConcatEmptyRight() {
        let left = Rope("Hello, world!")
        let right = Rope("")
        let rope = left + right
        XCTAssertEqual("Hello, world!", String(rope))
        XCTAssertEqual(13, rope.count)
        XCTAssertEqual(0, rope.root.height)
        XCTAssertIdentical(left.root, rope.root)
    }

    func testConcatEmptyMiddle() {
        let rope = Rope("Hello, ") + Rope("") + Rope("world!")
        XCTAssertEqual("Hello, world!", String(rope))
        XCTAssertEqual(13, rope.count)
        XCTAssertEqual(1, rope.root.height)
    }

    func testSplit() {
        let rope = Rope("Hello, world!")
        let (left, right) = rope.split(at: 7)

        XCTAssertEqual("Hello, ", String(left))
        XCTAssertEqual(7, left.count)

        XCTAssertEqual("world!", String(right))
        XCTAssertEqual(6, right.count)
    }

    func testConcatAndSplit() {
        let left = Rope("Hello, ")
        let right = Rope("world!")

        let rope = left + right
        let (left2, right2) = rope.split(at: 7)

        XCTAssertEqual("Hello, ", String(left2))
        XCTAssertEqual(7, left2.count)
        XCTAssertIdentical(left.root, left2.root)

        XCTAssertEqual("world!", String(right2))
        XCTAssertEqual(6, right2.count)
        XCTAssertIdentical(right.root, right2.root)
    }

    func testConcatAndSplitInsideString() {
        let left = Rope("Hello, ")
        let right = Rope("world!")

        let rope = left + right
        let (left2, right2) = rope.split(at: 5)

        XCTAssertEqual("Hello", String(left2))
        XCTAssertEqual(5, left2.count)
        XCTAssertNotIdentical(left.root, left2.root)

        XCTAssertEqual(", world!", String(right2))
        XCTAssertEqual(8, right2.count)
        XCTAssertNotIdentical(right.root, right2.root)
    }

    func testRangeSliceSimple() {
        let rope = Rope("Hello, world!")
        var slice = rope[7..<13]
        XCTAssertEqual("world!", String(slice))
        XCTAssertEqual(6, slice.count)

        slice = rope[0..<13]
        XCTAssertEqual("Hello, world!", String(slice))
        XCTAssertEqual(13, slice.count)
        XCTAssertIdentical(rope.root, slice.root)

        slice = rope[0..<5]
        XCTAssertEqual("Hello", String(slice))
        XCTAssertEqual(5, slice.count)

        slice = rope[1..<11]
        XCTAssertEqual("ello, worl", String(slice))
        XCTAssertEqual(10, slice.count)
    }

    func testRangeSliceSplitOnBoundary() {
        let left = Rope("Hello, ")
        let right = Rope("world!")

        let rope = left + right
        var slice = rope[7..<13]
        XCTAssertEqual("world!", String(slice))
        XCTAssertEqual(6, slice.count)
        XCTAssertIdentical(right.root, slice.root)

        slice = rope[0..<7]
        XCTAssertEqual("Hello, ", String(slice))
        XCTAssertEqual(7, slice.count)
        XCTAssertIdentical(left.root, slice.root)

        slice = rope[0..<5]
        XCTAssertEqual("Hello", String(slice))
        XCTAssertEqual(5, slice.count)
        XCTAssertNotIdentical(left.root, slice.root)
    }

    func testInsertCharacter() {
        var rope = Rope("abcefg")
        rope.insert("d", at: 3)
        XCTAssertEqual("abcdefg", String(rope))
        XCTAssertEqual(7, rope.count)
    }

    func testInsertString() {
        var rope = Rope("123789")
        rope.insert(contentsOf: "456", at: 3)
        XCTAssertEqual("123456789", String(rope))
        XCTAssertEqual(9, rope.count)
    }

    func testInsertCharacterIntoEmpty() {
        var rope = Rope("")
        rope.insert("a", at: 0)
        XCTAssertEqual("a", String(rope))
        XCTAssertEqual(1, rope.count)
        XCTAssertEqual(0, rope.root.height)
    }

    func testReplaceSubrange() {
        var rope = Rope("Hello, Earth!")
        rope.replaceSubrange(7..<12, with: "Moon")
        XCTAssertEqual("Hello, Moon!", String(rope))
        XCTAssertEqual(12, rope.count)
    }

    func testReplaceSubrangeWithEmpty() {
        var rope = Rope("Hello, world!")
        rope.replaceSubrange(5..<12, with: "")
        XCTAssertEqual("Hello!", String(rope))
        XCTAssertEqual(6, rope.count)
    }

    func testRemoveSubrange() {
        var rope = Rope("Hello, world!")
        rope.removeSubrange(5..<12)
        XCTAssertEqual("Hello!", String(rope))
        XCTAssertEqual(6, rope.count)
    }

    func testForIn() {
        let rope = Rope("Hello, world!")
        var result = ""

        for char in rope {
            result.append(char)
        }

        XCTAssertEqual("Hello, world!", result)
    }
}
