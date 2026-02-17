//
//  Item.swift
//  Cloudwrkz
//
//  Created by Niklas Vorberg on 13.02.26.
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
