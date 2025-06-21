//
//  Models.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//
import Foundation

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
    
    var targetMet: Bool {
        return steps >= targetSteps
    }
    
    var completionPercentage: Double {
        guard targetSteps > 0 else { return 0 }
        return min(Double(steps) / Double(targetSteps), 1.0)
    }
}

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
