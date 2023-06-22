//
//  NodePerformanceTests.swift
//
//
//  Created by David Albert on 6/20/23.
//

import XCTest
@testable import Rope

final class NodePerformanceTests: XCTestCase {
    func testUpdateInPlace() {
        let n = Rope.Node(Chunk(String(repeating: "a", count: 1_000_000)))

        self.measure(metrics: [XCTMemoryMetric()]) {
            for _ in 0..<10_000_000 {
                n.withMutableLeaf { chunk in
                    chunk.string.replaceSubrange(..<chunk.index(after: chunk.startIndex), with: "b")
                }
            }
        }
    }
}
