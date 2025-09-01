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

// MARK: - Main Inactivity History View
struct InactivityHistoryView: View {
    @ObservedObject var healthManager: HealthManager
    @State private var activityData: [DayActivityData] = []
    @State private var isLoading = true
    @State private var displayMode: ChartDisplayMode = .steps
    @State private var mostActiveTime: String = ""
    @State private var mostInactiveTime: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            InactivityHistoryHeaderView()
            
            if healthManager.authorizationStatus == "Authorized" {
                if isLoading {
                    InactivityLoadingView()
                } else {
                    ScrollView {
                        VStack(spacing: 25) {
                            // Summary Section
                            ActivitySummaryView(
                                mostActiveTime: mostActiveTime,
                                mostInactiveTime: mostInactiveTime
                            )
                            
                            // Mode Toggle
                            ChartModeToggle(displayMode: $displayMode)
                            
                            // Daily Charts
                            LazyVStack(spacing: 20) {
                                ForEach(activityData) { dayData in
                                    DailyActivityChart(
                                        dayData: dayData,
                                        displayMode: displayMode
                                    )
                                }
                            }
                            
                            // Bottom padding
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 50)
                        }
                        .padding()
                    }
                }
            } else {
                InactivityPermissionView {
                    healthManager.requestHealthKitPermission()
                }
            }
        }
        .onAppear {
            if healthManager.authorizationStatus == "Authorized" {
                fetchInactivityData()
            }
        }
        .onChange(of: healthManager.authorizationStatus) { status in
            if status == "Authorized" {
                fetchInactivityData()
            }
        }
    }
    
    private func fetchInactivityData() {
        isLoading = true
        
        // Fetch real hourly data from HealthKit
        healthManager.fetch30DayActivityData { [self] activityData in
            DispatchQueue.main.async {
                self.activityData = activityData
                self.calculateSummaryTimes()
                self.isLoading = false
            }
        }
    }
    
    private func calculateSummaryTimes() {
        // Calculate most active time across all days
        var hourlyTotals: [Int: Int] = [:]
        var hourlyNotifications: [Int: Int] = [:]
        
        for dayData in activityData {
            for hourData in dayData.hourlyData {
                // Only count waking hours (6 AM - 11 PM) for activity
                if hourData.hour >= 6 && hourData.hour < 23 {
                    hourlyTotals[hourData.hour, default: 0] += hourData.steps
                }
                hourlyNotifications[hourData.hour, default: 0] += hourData.notifications
            }
        }
        
        // Find most active hour
        if let mostActiveHour = hourlyTotals.max(by: { $0.value < $1.value })?.key {
            let formatter = DateFormatter()
            formatter.dateFormat = "h a"
            let hour = mostActiveHour == 0 ? 12 : (mostActiveHour > 12 ? mostActiveHour - 12 : mostActiveHour)
            let ampm = mostActiveHour < 12 ? "AM" : "PM"
            mostActiveTime = "\(hour) \(ampm)"
        }
        
        // Find most inactive hour (with most notifications)
        if let mostInactiveHour = hourlyNotifications.filter({ $0.value > 0 }).max(by: { $0.value < $1.value })?.key {
            let hour = mostInactiveHour == 0 ? 12 : (mostInactiveHour > 12 ? mostInactiveHour - 12 : mostInactiveHour)
            let ampm = mostInactiveHour < 12 ? "AM" : "PM"
            mostInactiveTime = "\(hour) \(ampm)"
        }
    }
    
    private func generateMockActivityData() -> [DayActivityData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var mockData: [DayActivityData] = []
        
        for dayOffset in 0..<30 {
            guard let dayDate = calendar.date(byAdding: .day, value: -29 + dayOffset, to: today) else { continue }
            
            var hourlyData: [HourlyStepData] = []
            var totalSteps = 0
            var totalNotifications = 0
            
            // Generate hourly data for each day
            for hour in 0..<24 {
                let steps = generateHourlySteps(hour: hour, dayOffset: dayOffset)
                let notifications = generateHourlyNotifications(hour: hour, dayOffset: dayOffset)
                
                hourlyData.append(HourlyStepData(
                    hour: hour,
                    steps: steps,
                    notifications: notifications
                ))
                
                totalSteps += steps
                totalNotifications += notifications
            }
            
            let targetSteps = healthManager.getTargetManager().getTargetForDate(dayDate)
            
            mockData.append(DayActivityData(
                date: dayDate,
                hourlyData: hourlyData,
                totalSteps: totalSteps,
                totalNotifications: totalNotifications,
                targetSteps: targetSteps
            ))
        }
        
        return mockData.sorted { $0.date > $1.date }
    }
    
    private func generateHourlySteps(hour: Int, dayOffset: Int) -> Int {
        // Sleep hours (11 PM - 6 AM): Very low activity
        if hour >= 23 || hour < 6 {
            return Int.random(in: 0...50)
        }
        
        // Morning hours (6-9 AM): Moderate activity
        if hour >= 6 && hour < 9 {
            return Int.random(in: 200...800)
        }
        
        // Work hours (9 AM - 5 PM): Variable activity
        if hour >= 9 && hour < 17 {
            // Some days more sedentary (meetings), others more active
            let isActiveMorning = dayOffset % 3 == 0
            return isActiveMorning ? Int.random(in: 100...400) : Int.random(in: 400...900)
        }
        
        // Evening hours (5-11 PM): Higher activity
        if hour >= 17 && hour < 23 {
            return Int.random(in: 300...1200)
        }
        
        return Int.random(in: 50...300)
    }
    
    private func generateHourlyNotifications(hour: Int, dayOffset: Int) -> Int {
        // No notifications during sleep
        if hour >= 23 || hour < 6 {
            return 0
        }
        
        // More likely to get notifications during work hours if sedentary
        if hour >= 9 && hour < 17 {
            // Simulate periods of inactivity
            if dayOffset % 4 == 0 && hour % 3 == 0 {
                return Int.random(in: 0...2)
            }
        }
        
        // Occasional notifications during other active hours
        if hour >= 6 && hour < 23 {
            return Int.random(in: 0...10) == 0 ? 1 : 0
        }
        
        return 0
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

//struct HourChartMarksView: View {
//    let hourData: HourlyStepData
//    let displayMode: ChartDisplayMode
//    let maxValue: Double
//    let sleepHours: [Int]
//    @Binding var selectedHour: Int?
//    
//    // You would need to move `formatHour`, `getBarColor`, and `getBarOpacity` into this view
//    // or a helper file.
//    private func getBarColor(for hourData: HourlyStepData) -> Color {
//        if selectedHour == hourData.hour {
//            return .white // Highlighted
//        }
//        
//        switch displayMode {
//        case .steps:
//            if sleepHours.contains(hourData.hour) {
//                return .stepperCream.opacity(0.4) // Muted for sleep hours
//            }
//            return .stepperLightTeal
//        case .notifications:
//            return .orange
//        }
//    }
//
//    private func getBarOpacity(for hourData: HourlyStepData) -> Double {
//        if selectedHour == hourData.hour {
//            return 1.0
//        }
//        if selectedHour != nil {
//            return 0.4 // Dim non-selected bars
//        }
//        return sleepHours.contains(hourData.hour) ? 0.6 : 0.8
//    }
//    
//    var body: some View {
//        // This is the content that was causing the compiler to fail
//        BarMark(
//            x: .value("Hour", hourData.hour),
//            y: .value(displayMode.rawValue, displayMode == .steps ? hourData.steps : hourData.notifications)
//        )
//        .foregroundStyle(getBarColor(for: hourData))
//        .opacity(getBarOpacity(for: hourData))
//        .cornerRadius(3)
//        
//        if sleepHours.contains(hourData.hour) {
//            RectangleMark(
//                x: .value("Hour", hourData.hour),
//                yStart: .value("Start", 0),
//                yEnd: .value("End", maxValue)
//            )
//            .zIndex(-1)
//        }
//    }
//}

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
    


