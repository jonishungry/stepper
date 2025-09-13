import Foundation
import SwiftUI

// MARK: - Step Data Model with Notification Count
struct StepData: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int
    let targetSteps: Int
    var inactivityNotifications: Int = 0  // NEW: Track daily notification count
    
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
    
    // NEW: Helper for notification status
    var notificationStatus: String {
        if inactivityNotifications == 0 {
            return "Active day"
        } else if inactivityNotifications == 1 {
            return "1 reminder"
        } else {
            return "\(inactivityNotifications) reminders"
        }
    }
}

// MARK: - Updated MenuItem with Inactivity
enum MenuItem: String, CaseIterable {
    case today = "Today's Steps"
    case history = "Step History"
    case notifications = "Notifications"
    
    var icon: String {
        switch self {
        case .today:
            return "figure.run"
        case .history:
            return "chart.bar.fill"
        case .notifications:
            return "bell.fill"
        }
    }
}

// MARK: - Color Theme
extension Color {
    static let stepperTeal = Color(red: 0.2, green: 0.4, blue: 0.45)
    static let stepperCream = Color(red: 0.96, green: 0.93, blue: 0.87)
    static let stepperLightTeal = Color(red: 0.4, green: 0.7, blue: 0.7)
    static let stepperDarkBlue = Color(red: 0.1, green: 0.15, blue: 0.2)
    static let stepperYellow = Color(red: 1.0, green: 0.85, blue: 0.4)
}
