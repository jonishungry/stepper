//
//  Models.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//

import Foundation

// MARK: - Menu Items
enum MenuItem: String, CaseIterable {
    case today = "Today's Steps"
    case history = "Step History"
    
    var icon: String {
        switch self {
        case .today:
            return "figure.walk"
        case .history:
            return "chart.bar"
        }
    }
}
