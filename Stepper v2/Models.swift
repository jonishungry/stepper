//
//  Models.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//
import Foundation
import SwiftUI

// MARK: - Step Data Model
struct StepData: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int
    let targetSteps: Int
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // Mon, Tue, etc.
        return formatter.string(from: date)
    }
    
    var fullDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    var weekday: Int {
        Calendar.current.component(.weekday, from: date)
    }
    
    var weekdayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Monday, Tuesday, etc.
        return formatter.string(from: date)
    }
    
    var targetMet: Bool {
        return steps >= targetSteps
    }
    
    var completionPercentage: Double {
        guard targetSteps > 0 else { return 0 }
        return min(Double(steps) / Double(targetSteps), 1.0)
    }
}

enum MenuItem: String, CaseIterable {
    case today = "Today's Steps"
    case history = "Step History"
    
    var icon: String {
        switch self {
        case .today:
            return "shoe.fill"  // Changed from "figure.walk"
        case .history:
            return "chart.bar.fill"  // Changed from "chart.bar"
        }
    }
}
// Add the new color theme:
// MARK: - Color Theme
extension Color {
    static let stepperTeal = Color(red: 0.2, green: 0.4, blue: 0.45)
    static let stepperCream = Color(red: 0.96, green: 0.93, blue: 0.87)
    static let stepperLightTeal = Color(red: 0.4, green: 0.7, blue: 0.7)
    static let stepperDarkBlue = Color(red: 0.1, green: 0.15, blue: 0.2)
    static let stepperYellow = Color(red: 1.0, green: 0.85, blue: 0.4)
}
