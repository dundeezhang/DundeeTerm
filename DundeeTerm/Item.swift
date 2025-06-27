//
//  Item.swift
//  DundeeTerm
//
//  Created by Dundee Zhang on 2025-06-26.
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
