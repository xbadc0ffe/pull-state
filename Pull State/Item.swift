//
//  Item.swift
//  Pull State
//
//  Created by Robert Morris on 4/26/26.
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
