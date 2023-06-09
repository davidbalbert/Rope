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
}
