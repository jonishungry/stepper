//
//  InactivityHistoryView.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 9/1/25.
//

import SwiftUI
import Charts
import HealthKit

// MARK: - Hourly Data Models
struct HourlyStepData: Identifiable {
    let id = UUID()
    let hour: Int // 0-23
    let steps: Int
    let notifications: Int
    
    var hourString: String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
}

struct DayActivityData: Identifiable {
    let id = UUID()
    let date: Date
    let hourlyData: [HourlyStepData]
    let totalSteps: Int
    let totalNotifications: Int
    let targetSteps: Int
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    var fullDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    // Most active hour (excluding sleep hours 11 PM - 6 AM)
    var mostActiveHour: Int? {
        let wakingHours = hourlyData.filter { $0.hour >= 6 && $0.hour < 23 }
        return wakingHours.max(by: { $0.steps < $1.steps })?.hour
    }
    
    // Most inactive hour with notifications
    var mostInactiveHour: Int? {
        let hoursWithNotifications = hourlyData.filter { $0.notifications > 0 }
        return hoursWithNotifications.max(by: { $0.notifications < $1.notifications })?.hour
    }
}

// MARK: - Chart Display Mode
enum ChartDisplayMode: String, CaseIterable {
    case steps = "Steps"
    case notifications = "Notifications"
    
    var icon: String {
        switch self {
        case .steps:
            return "figure.walk"
        case .notifications:
            return "bell.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .steps:
            return .stepperLightTeal
        case .notifications:
            return .orange
        }
    }
}

// MARK: - Average Activity Data Model
struct AverageActivityData {
    let hourlyAverageSteps: [Int: Double] // hour -> average steps
    let hourlyAverageNotifications: [Int: Double] // hour -> average notifications
    let totalDays: Int
    let mostActiveHour: Int
    let mostInactiveHour: Int // hour with most notifications
    let mostActiveSteps: Int // steps in most active hour
    let averageStepsInActiveHour: Double
}

struct InactivityHistoryView: View {
    @ObservedObject var healthManager: HealthManager
    @State private var averageActivityData: AverageActivityData?
    @State private var isLoading = true
    @State private var displayMode: ChartDisplayMode = .steps
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            InactivityHistoryHeaderView()
            
            if healthManager.authorizationStatus == "Authorized" {
                if isLoading {
                    InactivityLoadingView()
                } else if let averageData = averageActivityData {
                    ScrollView {
                        VStack(spacing: 25) {
                            // Enhanced Activity Summary
                            EnhancedActivitySummaryView(averageData: averageData)
                            
                            // Mode Toggle
                            ChartModeToggle(displayMode: $displayMode)
                            
                            // Average Activity Chart
                            AverageActivityChart(
                                averageData: averageData,
                                displayMode: displayMode
                            )
                            
                            // Activity Insights
                            ActivityInsightsView(averageData: averageData)
                            
                            // Bottom padding
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 50)
                        }
                        .padding()
                    }
                } else {
                    Text("No activity data available")
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
            } else {
                InactivityPermissionView {
                    healthManager.requestHealthKitPermission()
                }
            }
        }
        .onAppear {
            if healthManager.authorizationStatus == "Authorized" {
                fetchAverageActivityData()
            }
        }
        .onChange(of: healthManager.authorizationStatus) { status in
            if status == "Authorized" {
                fetchAverageActivityData()
            }
        }
    }
    
    private func fetchAverageActivityData() {
        isLoading = true
        
        healthManager.fetch30DayActivityData { activityData in
            DispatchQueue.main.async {
                self.averageActivityData = self.calculateAverageActivityData(from: activityData)
                self.isLoading = false
            }
        }
    }
    
    private func calculateAverageActivityData(from activityData: [DayActivityData]) -> AverageActivityData {
        var hourlyStepTotals: [Int: Double] = [:]
        var hourlyNotificationTotals: [Int: Double] = [:]
        var hourlyDayCounts: [Int: Int] = [:]
        
        // Aggregate data across all days
        for dayData in activityData {
            for hourData in dayData.hourlyData {
                let hour = hourData.hour
                
                hourlyStepTotals[hour, default: 0] += Double(hourData.steps)
                hourlyNotificationTotals[hour, default: 0] += Double(hourData.notifications)
                hourlyDayCounts[hour, default: 0] += 1
            }
        }
        
        // Calculate averages
        var hourlyAverageSteps: [Int: Double] = [:]
        var hourlyAverageNotifications: [Int: Double] = [:]
        
        for hour in 0..<24 {
            let dayCount = hourlyDayCounts[hour] ?? 1
            hourlyAverageSteps[hour] = (hourlyStepTotals[hour] ?? 0) / Double(dayCount)
            hourlyAverageNotifications[hour] = (hourlyNotificationTotals[hour] ?? 0) / Double(dayCount)
        }
        
        // Find most active hour (excluding sleep hours 11 PM - 6 AM)
        let wakingHours = Array(6..<23)
        let mostActiveHour = wakingHours.max { hour1, hour2 in
            (hourlyAverageSteps[hour1] ?? 0) < (hourlyAverageSteps[hour2] ?? 0)
        } ?? 12
        
        // Find most inactive hour (most notifications, excluding sleep hours)
        let mostInactiveHour = wakingHours.max { hour1, hour2 in
            (hourlyAverageNotifications[hour1] ?? 0) < (hourlyAverageNotifications[hour2] ?? 0)
        } ?? 14
        
        let mostActiveSteps = Int(hourlyAverageSteps[mostActiveHour] ?? 0)
        let averageStepsInActiveHour = hourlyAverageSteps[mostActiveHour] ?? 0
        
        return AverageActivityData(
            hourlyAverageSteps: hourlyAverageSteps,
            hourlyAverageNotifications: hourlyAverageNotifications,
            totalDays: activityData.count,
            mostActiveHour: mostActiveHour,
            mostInactiveHour: mostInactiveHour,
            mostActiveSteps: mostActiveSteps,
            averageStepsInActiveHour: averageStepsInActiveHour
        )
    }
}

// MARK: - Enhanced Activity Summary
struct EnhancedActivitySummaryView: View {
    let averageData: AverageActivityData
    
    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.stepperYellow)
                Text("Activity Patterns")
                    .font(.headline)
                    .foregroundColor(.stepperCream)
                Text("(\(averageData.totalDays) days)")
                    .font(.caption)
                    .foregroundColor(.stepperCream.opacity(0.7))
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.stepperYellow)
            }
            
            // Activity insights
            VStack(spacing: 15) {
                HStack(spacing: 30) {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("Peak Activity")
                            .font(.caption)
                            .foregroundColor(.stepperCream.opacity(0.7))
                        
                        Text(formatHour(averageData.mostActiveHour))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        Text("\(averageData.mostActiveSteps) steps avg")
                            .font(.caption2)
                            .foregroundColor(.green.opacity(0.8))
                    }
                    
                    VStack(spacing: 8) {
                        Image(systemName: "bell.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("Most Inactive")
                            .font(.caption)
                            .foregroundColor(.stepperCream.opacity(0.7))
                        
                        Text(formatHour(averageData.mostInactiveHour))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Text("\(String(format: "%.1f", averageData.hourlyAverageNotifications[averageData.mostInactiveHour] ?? 0)) reminders avg")
                            .font(.caption2)
                            .foregroundColor(.orange.opacity(0.8))
                    }
                }
                
                // Insights based on patterns
                VStack(spacing: 10) {
                    Divider()
                        .background(Color.stepperCream.opacity(0.3))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("💡")
                                .font(.title3)
                            Text("Activity Insights")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.stepperYellow)
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if averageData.mostActiveHour < 12 {
                                Text("• You're most active in the morning - great for metabolism! 🌅")
                            } else if averageData.mostActiveHour >= 17 {
                                Text("• You prefer evening activity - perfect for unwinding! 🌆")
                            } else {
                                Text("• Your peak activity is during midday - steady energy! ☀️")
                            }
                            
                            let avgNotifications = averageData.hourlyAverageNotifications.values.reduce(0, +) / Double(averageData.hourlyAverageNotifications.count)
                            if avgNotifications < 0.5 {
                                Text("• Excellent consistency - you stay active throughout the day! 🎉")
                            } else {
                                Text("• Consider scheduling movement breaks around \(formatHour(averageData.mostInactiveHour))")
                            }
                            
                            let totalAvgSteps = averageData.hourlyAverageSteps.values.reduce(0, +)
                            if totalAvgSteps > 8000 {
                                Text("• Great activity level - you average \(Int(totalAvgSteps)) steps per day! 👏")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.8))
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.stepperTeal.opacity(0.3))
        )
    }
}

// MARK: - Average Activity Chart
struct AverageActivityChart: View {
    let averageData: AverageActivityData
    let displayMode: ChartDisplayMode
    @State private var selectedHour: Int? = nil
    
    private var chartData: [(hour: Int, value: Double)] {
        switch displayMode {
        case .steps:
            return averageData.hourlyAverageSteps.map { (hour: $0.key, value: $0.value) }.sorted { $0.hour < $1.hour }
        case .notifications:
            return averageData.hourlyAverageNotifications.map { (hour: $0.key, value: $0.value) }.sorted { $0.hour < $1.hour }
        }
    }
    
    private var maxValue: Double {
        let maxVal = chartData.map(\.value).max() ?? 1000
        return maxVal * 1.1 // Add 10% padding
    }
    
    private var sleepHours: [Int] {
        return [23, 0, 1, 2, 3, 4, 5] // 11 PM to 5 AM
    }
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Average \(displayMode.rawValue) by Hour")
                    .font(.headline)
                    .foregroundColor(.stepperCream)
                Spacer()
                Text("Last \(averageData.totalDays) days")
                    .font(.caption)
                    .foregroundColor(.stepperCream.opacity(0.7))
            }
            
            // Selected Hour Detail
            if let selectedHour = selectedHour {
                HourAverageDetailView(
                    hour: selectedHour,
                    averageData: averageData,
                    displayMode: displayMode
                )
            }
            
            // Chart
            Chart(chartData, id: \.hour) { data in
                BarMark(
                    x: .value("Hour", data.hour),
                    y: .value(displayMode.rawValue, data.value)
                )
                .foregroundStyle(getBarColor(for: data.hour))
                .opacity(getBarOpacity(for: data.hour))
                .cornerRadius(3)
                
                // Highlight most active/inactive hour
                if (displayMode == .steps && data.hour == averageData.mostActiveHour) ||
                   (displayMode == .notifications && data.hour == averageData.mostInactiveHour) {
                    BarMark(
                        x: .value("Hour", data.hour),
                        y: .value(displayMode.rawValue, data.value)
                    )
                    .foregroundStyle(.white.opacity(0.3))
                    .cornerRadius(3)
                }
            }
            .chartXScale(domain: 0...23)
            .chartYScale(domain: 0...maxValue)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    if let hour = value.as(Int.self) {
                        AxisGridLine()
                            .foregroundStyle(Color.stepperCream.opacity(0.2))
                        AxisValueLabel {
                            Text(formatHour(hour))
                                .font(.caption2)
                                .foregroundColor(Color.stepperCream.opacity(0.7))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.stepperCream.opacity(0.15))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(Int(doubleValue))")
                                .font(.caption2)
                                .foregroundColor(Color.stepperCream.opacity(0.6))
                        }
                    }
                }
            }
            .frame(height: 200)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.stepperCream.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(displayMode.color.opacity(0.3), lineWidth: 1)
                    )
            )
            .onTapGesture { location in
                let chartWidth = UIScreen.main.bounds.width - 80
                let hourWidth = chartWidth / 24
                let tappedHour = Int(location.x / hourWidth)
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedHour = tappedHour == selectedHour ? nil : min(23, max(0, tappedHour))
                }
            }
        }
    }
    
    private func getBarColor(for hour: Int) -> Color {
        if selectedHour == hour {
            return .white
        }
        
        switch displayMode {
        case .steps:
            if hour == averageData.mostActiveHour {
                return .green
            }
            if sleepHours.contains(hour) {
                return .stepperCream.opacity(0.4)
            }
            return .stepperLightTeal
        case .notifications:
            if hour == averageData.mostInactiveHour {
                return .red
            }
            return .orange
        }
    }
    
    private func getBarOpacity(for hour: Int) -> Double {
        if selectedHour == hour {
            return 1.0
        }
        if selectedHour != nil {
            return 0.4
        }
        return sleepHours.contains(hour) ? 0.6 : 0.8
    }
    
    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
}

// MARK: - Hour Average Detail View
struct HourAverageDetailView: View {
    let hour: Int
    let averageData: AverageActivityData
    let displayMode: ChartDisplayMode
    
    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("📊 \(formatHour(hour)) Average")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.stepperYellow)
            
            HStack(spacing: 20) {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.stepperLightTeal)
                    Text("\(Int(averageData.hourlyAverageSteps[hour] ?? 0)) steps")
                        .font(.caption)
                        .foregroundColor(.stepperCream)
                }
                
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                    Text(String(format: "%.1f reminders", averageData.hourlyAverageNotifications[hour] ?? 0))
                        .font(.caption)
                        .foregroundColor(.stepperCream)
                }
                
                // Special indicators
                if displayMode == .steps && hour == averageData.mostActiveHour {
                    Text("🏃‍♂️ Peak!")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                if displayMode == .notifications && hour == averageData.mostInactiveHour {
                    Text("⚠️ Most Inactive")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.stepperDarkBlue.opacity(0.7))
        )
    }
}

// MARK: - Activity Insights View
struct ActivityInsightsView: View {
    let averageData: AverageActivityData
    
    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
    
    private var activityScore: Int {
        let totalSteps = averageData.hourlyAverageSteps.values.reduce(0, +)
        let totalNotifications = averageData.hourlyAverageNotifications.values.reduce(0, +)
        
        // Simple scoring: more steps = better, fewer notifications = better
        let stepScore = min(100, Int(totalSteps / 100))
        let notificationPenalty = min(50, Int(totalNotifications * 5))
        
        return max(0, stepScore - notificationPenalty)
    }
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.stepperYellow)
                Text("Activity Score: \(activityScore)/100")
                    .font(.headline)
                    .foregroundColor(.stepperCream)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Peak performance window
                HStack {
                    Text("🎯")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Peak Performance Window")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        Text("Schedule important activities around \(formatHour(averageData.mostActiveHour)) when you average \(averageData.mostActiveSteps) steps per hour")
                            .font(.caption)
                            .foregroundColor(.stepperCream.opacity(0.8))
                    }
                    Spacer()
                }
                
                // Improvement opportunity
                if averageData.hourlyAverageNotifications[averageData.mostInactiveHour] ?? 0 > 0.5 {
                    HStack {
                        Text("⚡")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Movement Opportunity")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Text("Set a \(formatHour(averageData.mostInactiveHour)) movement reminder - this is when you're typically least active")
                                .font(.caption)
                                .foregroundColor(.stepperCream.opacity(0.8))
                        }
                        Spacer()
                    }
                }
                
                // Consistency insight
                let consistentHours = averageData.hourlyAverageSteps.filter { $0.value > 200 && ![23, 0, 1, 2, 3, 4, 5].contains($0.key) }.count
                if consistentHours > 12 {
                    HStack {
                        Text("🌟")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Consistency Champion")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.stepperYellow)
                            Text("You maintain good activity across \(consistentHours) hours of the day - excellent consistency!")
                                .font(.caption)
                                .foregroundColor(.stepperCream.opacity(0.8))
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.stepperCream.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.stepperYellow.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Subviews
struct InactivityHistoryHeaderView: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Activity Patterns")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.stepperCream)
            }
            
            Text("30-day hourly activity and inactivity analysis")
                .font(.subheadline)
                .foregroundColor(.stepperCream.opacity(0.8))
        }
    }
}

struct InactivityLoadingView: View {
    var body: some View {
        VStack(spacing: 15) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .stepperYellow))
                .scaleEffect(1.5)
            
            Text("Analyzing your activity patterns...")
                .foregroundColor(.stepperCream.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InactivityPermissionView: View {
    let requestPermission: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundColor(.stepperYellow)
            
            Text("Health Access Needed")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.stepperCream)
            
            Text("Enable Health access to view your detailed activity patterns!")
                .multilineTextAlignment(.center)
                .foregroundColor(.stepperCream.opacity(0.8))
            
            Button(action: requestPermission) {
                Text("Enable Health Access 📊")
                    .font(.headline)
                    .foregroundColor(.stepperDarkBlue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.stepperYellow)
                    .cornerRadius(16)
            }
        }
        .padding()
    }
}

struct ActivitySummaryView: View {
    let mostActiveTime: String
    let mostInactiveTime: String
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.stepperYellow)
                Text("Activity Summary")
                    .font(.headline)
                    .foregroundColor(.stepperCream)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.stepperYellow)
            }
            
            // Time-based insights
            VStack(spacing: 15) {
                HStack(spacing: 30) {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("Peak Activity")
                            .font(.caption)
                            .foregroundColor(.stepperCream.opacity(0.7))
                        
                        Text(mostActiveTime.isEmpty ? "Calculating..." : mostActiveTime)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    VStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("Most Reminders")
                            .font(.caption)
                            .foregroundColor(.stepperCream.opacity(0.7))
                        
                        Text(mostInactiveTime.isEmpty ? "Great job!" : mostInactiveTime)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
                
                // Additional insights
                VStack(spacing: 10) {
                    Divider()
                        .background(Color.stepperCream.opacity(0.3))
                    
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("💡")
                                .font(.title3)
                            Text("Insights")
                                .font(.caption2)
                                .foregroundColor(.stepperCream.opacity(0.7))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if mostActiveTime.contains("AM") && Int(mostActiveTime.prefix(2)) ?? 0 < 10 {
                                Text("• You're a morning person! 🌅")
                            } else if mostActiveTime.contains("PM") && Int(mostActiveTime.prefix(2)) ?? 0 > 6 {
                                Text("• You prefer evening workouts! 🌆")
                            } else {
                                Text("• Consistent activity throughout the day!")
                            }
                            
                            if mostInactiveTime.isEmpty {
                                Text("• Excellent activity consistency! 🎉")
                            } else {
                                Text("• Consider setting reminders around \(mostInactiveTime)")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.8))
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.stepperTeal.opacity(0.3))
        )
    }
}

struct ChartModeToggle: View {
    @Binding var displayMode: ChartDisplayMode
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ChartDisplayMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayMode = mode
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: mode.icon)
                        Text(mode.rawValue)
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(displayMode == mode ? .stepperDarkBlue : .stepperCream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        displayMode == mode ?
                        Color.stepperYellow :
                        Color.clear
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.stepperCream.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.stepperYellow.opacity(0.3), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DayHeaderView: View {
    let dayData: DayActivityData
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(dayData.dayName) • \(dayData.fullDate)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.stepperCream)
                    
                    if dayData.isToday {
                        Text("Today")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.stepperDarkBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.stepperYellow)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 20) {
                    Text("\(dayData.totalSteps) steps")
                        .font(.caption)
                        .foregroundColor(.stepperLightTeal)
                        .fontWeight(.medium)
                    
                    if dayData.totalNotifications > 0 {
                        Text("\(dayData.totalNotifications) reminders")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    } else {
                        Text("No reminders")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                    
                    // Goal status
                    if dayData.totalSteps >= dayData.targetSteps {
                        Text("Goal met! 🎯")
                            .font(.caption)
                            .foregroundColor(.stepperYellow)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
    
}
struct HourDetailView: View {
    let hourData: HourlyStepData

    var body: some View {
        VStack(spacing: 8) {
            Text("📊 \(hourData.hourString)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.stepperYellow)

            HStack(spacing: 20) {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.stepperLightTeal)
                    Text("\(hourData.steps) steps")
                        .font(.caption)
                        .foregroundColor(.stepperCream)
                }

                if hourData.notifications > 0 {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                        Text("\(hourData.notifications) reminder\(hourData.notifications == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.stepperCream)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.stepperDarkBlue.opacity(0.7))
        )
    }
}

struct ActivityChartView: View {
    let chartData: [HourlyStepData]
    let displayMode: ChartDisplayMode
    let maxValue: Int
    let sleepHours: [Int]
    @Binding var selectedHour: Int?
    
    var body: some View {
        Chart(chartData) { data in
            BarMark(
                x: .value("Hour", data.hour),
                y: .value(displayMode.rawValue, displayMode == .steps ? data.steps : data.notifications)
            )
            .foregroundStyle(getBarColor(for: data))
            .opacity(getBarOpacity(for: data))
            .cornerRadius(3)
            
        }
        .chartXScale(domain: 0...23)
        .chartYScale(domain: 0...maxValue)
        .chartXAxis {self.buildAxisMarks()}
        .chartYAxis {self.buildYAxisMarks()}
        .frame(height: 140)
        .padding()
        .background()
        .onTapGesture { location in
            let chartWidth = UIScreen.main.bounds.width - 80
            let hourWidth = chartWidth / 24
            let tappedHour = Int(location.x / hourWidth)
            
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedHour = tappedHour == selectedHour ? nil : tappedHour
            }
        }
    }

    @AxisContentBuilder
    private func buildAxisMarks()  -> some AxisContent{
        AxisMarks(values: [0, 6, 12, 18, 23]) { value in
            if let hour = value.as(Int.self) {
                AxisGridLine()
                    .foregroundStyle(Color.stepperCream.opacity(0.2))
                AxisValueLabel {
                    Text(formatHour(hour))
                        .font(.caption2)
                        .foregroundColor(Color.stepperCream.opacity(0.7))
                }
            }
        }
    }
    
    @AxisContentBuilder
    private func buildYAxisMarks() -> some AxisContent{
        AxisMarks(position: .leading) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(Color.stepperCream.opacity(0.15))
            AxisValueLabel {
                if let intValue = value.as(Int.self) {
                    Text("\(intValue)")
                        .font(.caption2)
                        .foregroundColor(Color.stepperCream.opacity(0.6))
                }
            }
        }
    }
    
    private func getBarColor(for hourData: HourlyStepData) -> Color {
            if selectedHour == hourData.hour {
                return .white // Highlighted
            }
    
            switch displayMode {
            case .steps:
                if sleepHours.contains(hourData.hour) {
                    return .stepperCream.opacity(0.4) // Muted for sleep hours
                }
                return .stepperLightTeal
            case .notifications:
                return .orange
            }
        }
    
        private func getBarOpacity(for hourData: HourlyStepData) -> Double {
            if selectedHour == hourData.hour {
                return 1.0
            }
            if selectedHour != nil {
                return 0.4 // Dim non-selected bars
            }
            return sleepHours.contains(hourData.hour) ? 0.6 : 0.8
        }
        
    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
    
    
    
    
}
struct BackgroundView: View {
    let displayMode: ChartDisplayMode
    var body: some View {RoundedRectangle(cornerRadius: 12)
            .fill(Color.stepperCream.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(displayMode.color.opacity(0.3), lineWidth: 1)
            )
    }
}
struct DailyActivityChart: View {
    let dayData: DayActivityData
    let displayMode: ChartDisplayMode
    @State private var selectedHour: Int? = nil
    
    private var chartData: [HourlyStepData] {
        return dayData.hourlyData
    }
    
    private var maxValue: Int {
        switch displayMode {
        case .steps:
            let maxSteps = chartData.map(\.steps).max() ?? 1000
            return Int(Double(maxSteps) * 1.1) // Add 10% padding
        case .notifications:
            let maxNotifications = chartData.map(\.notifications).max() ?? 1
            return max(maxNotifications + 1, 3) // Minimum scale of 3 for visibility
        }
    }
    
    private var sleepHours: [Int] {
        return [23, 0, 1, 2, 3, 4, 5] // 11 PM to 5 AM
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // Day Header
            DayHeaderView(dayData: dayData) // Use the new subview
            
            // Selected Hour Detail
            if let selectedHour = selectedHour,
               let hourData = chartData.first(where: { $0.hour == selectedHour }) {
                HourDetailView(hourData: hourData) // Use the new subview
            }
            
            
            // Chart
            ActivityChartView(chartData: chartData, displayMode: displayMode, maxValue: maxValue, sleepHours: sleepHours, selectedHour: $selectedHour) // Use the new subview
            
        }
    }
}
    


