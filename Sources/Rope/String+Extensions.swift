//
//  String+Extensions.swift
//
//
//  Created by David Albert on 6/26/23.
//

import Foundation

extension StringProtocol {
    func index(at offset: Int) -> Index {
        index(startIndex, offsetBy: offset)
    }

    func utf8Index(at offset: Int) -> Index {
        utf8.index(startIndex, offsetBy: offset)
    }
}
