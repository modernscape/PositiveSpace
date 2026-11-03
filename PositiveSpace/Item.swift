//
//  Item.swift
//  PositiveSpace
//
//  Created by forest on 2026/11/03.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
