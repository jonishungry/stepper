import SwiftUI
import Charts

// MARK: - Step History View
struct StepHistoryView: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        VStack(spacing: 20) {
            StepHistoryHeaderView()
            
            if healthManager.authorizationStatus == "Authorized" {
                if healthManager.weeklySteps.isEmpty {
                    StepHistoryLoadingView()
                } else {
                    StepHistoryContentView(
                        weeklySteps: healthManager.weeklySteps,
                        healthManager: healthManager,
                        refreshAction: {
                            healthManager.fetchWeeklySteps()
                        }
                    )
                }
            } else {
                StepHistoryPermissionView(requestPermission: {
                    healthManager.requestHealthKitPermission()
                })
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Step History Subviews
struct StepHistoryHeaderView: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Step History")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.stepperCream)
            
            }
        }
    }
}

struct StepHistoryLoadingView: View {
    var body: some View {
        VStack(spacing: 15) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .stepperYellow))
                .scaleEffect(1.5)
            
            Text("Fetching your step data...")
                .foregroundColor(.stepperCream.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StepHistoryContentView: View {
    let weeklySteps: [StepData]
    @ObservedObject var healthManager: HealthManager
    let refreshAction: () -> Void
    @State private var selectedDay: StepData?
    @State private var showingDayDetail = false
    
    var body: some View {
        VStack(spacing: 20) {
            StepHistoryChartView(
                weeklySteps: weeklySteps,
                healthManager: healthManager
            )
            StepHistoryLegendView()
            StepHistoryStatsView(weeklySteps: weeklySteps)
        }
        .onAppear {
            refreshAction()
        }
        .overlay(
            // Overlay positioned with .overlay to not affect layout
            Group {
                if showingDayDetail, let selectedDay = selectedDay {
                    DayDetailOverlay(
                        stepData: selectedDay,
                        healthManager: healthManager,
                        isPresented: $showingDayDetail
                    )
                }
            }
        )
    }
}

struct StepHistoryChartView: View {
    let weeklySteps: [StepData]
    @ObservedObject var healthManager: HealthManager
    @State private var selectedDay: StepData?
    @State private var showingDayDetail = false
    
    private var sortedSteps: [StepData] {
        return weeklySteps.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        ZStack {
            VStack {
                ScrollView(.horizontal, showsIndicators: true) {
                    ZStack {
                        Chart(sortedSteps) { stepData in
                            BarMark(
                                x: .value("Date", stepData.date, unit: .day),
                                y: .value("Steps", stepData.steps)
                            )
                            .foregroundStyle(getBarColor(for: stepData))
                            .opacity(0.9)
                            .cornerRadius(6)
                            
                            PointMark(
                                x: .value("Date", stepData.date, unit: .day),
                                y: .value("Target", stepData.targetSteps)
                            )
                            .symbol(Circle())
                            .symbolSize(isSelected(stepData) ? 140 : 100)
                            .foregroundStyle(isSelected(stepData) ? Color.white : Color.stepperCream)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { value in
                                if let date = value.as(Date.self) {
                                    AxisGridLine()
                                    AxisValueLabel {
                                        VStack(spacing: 2) {
                                            Text(dayFormatter.string(from: date))
                                                .font(.caption2)
                                                .foregroundColor(isDateSelected(date) ? .white : .stepperCream)
                                                .fontWeight(isDateSelected(date) ? .bold : .regular)
                                            Text(dateFormatter.string(from: date))
                                                .font(.caption2)
                                                .foregroundColor(isDateSelected(date) ? .white.opacity(0.9) : .stepperCream.opacity(0.8))
                                                .fontWeight(isDateSelected(date) ? .semibold : .regular)
                                        }
                                    }
                                }
                            }
                        }
                        .chartYScale(domain: 0...maxChartValue)
                        .frame(width: CGFloat(sortedSteps.count) * 60, height: 300)
                        .animation(.easeInOut(duration: 0.2), value: selectedDay?.id)
                        
                        // Invisible tap detection overlay
                        HStack(spacing: 0) {
                            ForEach(Array(sortedSteps.enumerated()), id: \.element.id) { index, stepData in
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 60, height: 300)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        handleBarTap(stepData)
                                    }
                            }
                        }
                    }
                    .padding()
                }
                .background(ChartBackgroundStyle())
                
                Text("Swipe to see more days • Tap any bar for details")
                    .font(.caption)
                    .foregroundColor(.stepperCream.opacity(0.6))
            }
            
            // Overlay Day Detail View
            if showingDayDetail, let selectedDay = selectedDay {
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        showingDayDetail = false
                                    }
                                }
                            
                            DayDetailOverlay(
                                stepData: selectedDay,
                                healthManager: healthManager,
                                isPresented: $showingDayDetail
                            )
                        }
        }
        .animation(.easeInOut(duration: 0.2), value: showingDayDetail)
    }
    
    // MARK: - Helper Functions
    private func handleBarTap(_ stepData: StepData) {
        print("📊 Tapped bar for \(stepData.weekdayName) \(stepData.fullDate)")
        
        if isSelected(stepData) {
            // Tapping already selected bar - deselect it
            print("🔄 Deselecting bar")
            withAnimation(.easeOut(duration: 0.2)) {
                selectedDay = nil
                showingDayDetail = false
            }
        } else {
            // Tapping new bar - select it
            print("✅ Selecting new bar")
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDay = stepData
                showingDayDetail = true
            }
        }
    }
    
    private func isSelected(_ stepData: StepData) -> Bool {
        return selectedDay?.id == stepData.id
    }
    
    private func getBarColor(for stepData: StepData) -> Color {
        if isSelected(stepData) {
            // Selected bar - bright white
            return Color.white
        } else {
            // Normal bar colors
            return stepData.targetMet ? Color.stepperYellow : Color.stepperLightTeal
        }
    }
    
    private func isDateSelected(_ date: Date) -> Bool {
        guard let selectedDay = selectedDay else { return false }
        let calendar = Calendar.current
        return calendar.isDate(date, inSameDayAs: selectedDay.date)
    }
    
    private var maxChartValue: Int {
        let maxSteps = sortedSteps.map(\.steps).max() ?? 0
        let maxTarget = sortedSteps.map(\.targetSteps).max() ?? 0
        return Int(Double(max(maxSteps, maxTarget)) * 1.1)
    }
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }
}

struct ChartBackgroundStyle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.stepperCream.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.stepperYellow.opacity(0.3), lineWidth: 2)
            )
    }
}

struct StepHistoryLegendView: View {
    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.stepperLightTeal)
                    .frame(width: 12, height: 12)
                    .cornerRadius(3)
                Text("Steps")
                    .font(.caption)
                    .foregroundColor(.stepperCream.opacity(0.8))
            }
            
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.stepperYellow)
                    .frame(width: 12, height: 12)
                    .cornerRadius(3)
                Text("Goal Reached!")
                    .font(.caption)
                    .foregroundColor(.stepperCream.opacity(0.8))
            }
            
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.stepperCream)
                    .frame(width: 10, height: 10)
                Text("Daily Goal")
                    .font(.caption)
                    .foregroundColor(.stepperCream.opacity(0.8))
            }
        }
    }
}

struct StepHistoryStatsView: View {
    let weeklySteps: [StepData]
    
    private var sortedSteps: [StepData] {
        return weeklySteps.sorted { $0.date < $1.date }
    }
    
    private var totalNotifications: Int {
        return sortedSteps.map(\.inactivityNotifications).reduce(0, +)
    }
    
    private var averageNotifications: Double {
        let total = totalNotifications
        let count = sortedSteps.count
        return count > 0 ? Double(total) / Double(count) : 0
    }
    
    private var dayCount: Int {
        return sortedSteps.count
    }
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "shoeprints.fill")
                    .foregroundColor(.stepperYellow)
                Text("Last \(dayCount) Days Summary")
                    .font(.headline)
                    .foregroundColor(.stepperCream)
                Image(systemName: "shoeprints.fill")
                    .foregroundColor(.stepperYellow)
            }
            
            // First row: Steps stats
            HStack(spacing: 20) {
                VStack {
                    Text("\(sortedSteps.map(\.steps).reduce(0, +))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.stepperYellow)
                    Text("Total Steps")
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
                
                VStack {
                    Text("\(sortedSteps.map(\.steps).reduce(0, +) / max(sortedSteps.count, 1))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.stepperLightTeal)
                    Text("Daily Average")
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
                
                VStack {
                    Text("\(sortedSteps.filter(\.targetMet).count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.stepperCream)
                    Text("Goals Met")
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
            }
            
            
            // Summary message
            if totalNotifications == 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Excellent! Stayed active for \(dayCount) days! 🎉")
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                }
            } else if averageNotifications > 2 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Consider staying more active throughout the day")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.stepperTeal.opacity(0.3))
        )
    }
}

struct StepHistoryPermissionView: View {
    let requestPermission: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.stepperYellow)
            
            Text("Health Access Needed")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.stepperCream)
            
            Text("Enable Health access to see your step history!")
                .multilineTextAlignment(.center)
                .foregroundColor(.stepperCream.opacity(0.8))
            
            Button(action: requestPermission) {
                Text("Enable Health Access 👟")
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
