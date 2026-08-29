//
//  Item.swift
//  PantryBuddy
//
//  Created by Federico Costa on 30/08/2026.
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
