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
                    Chart(sortedSteps) { stepData in
                        BarMark(
                            x: .value("Date", stepData.date, unit: .day),
                            y: .value("Steps", stepData.steps)
                        )
                        .foregroundStyle(stepData.targetMet ? Color.stepperYellow : Color.stepperLightTeal)
                        .opacity(selectedDay?.id == stepData.id ? 1.0 : 0.7)
                        .cornerRadius(6)
                        
                        PointMark(
                            x: .value("Date", stepData.date, unit: .day),
                            y: .value("Target", stepData.targetSteps)
                        )
                        .symbol(Circle())
                        .symbolSize(selectedDay?.id == stepData.id ? 140 : 100)
                        .foregroundStyle(Color.stepperCream)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            if let date = value.as(Date.self) {
                                AxisGridLine()
                                AxisValueLabel {
                                    VStack(spacing: 2) {
                                        Text(dayFormatter.string(from: date))
                                            .font(.caption2)
                                            .foregroundColor(.stepperCream)
                                        Text(dateFormatter.string(from: date))
                                            .font(.caption2)
                                            .foregroundColor(.stepperCream.opacity(0.8))
                                    }
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...maxChartValue)
                    .frame(width: CGFloat(sortedSteps.count) * 60, height: 300)
                    .padding()
                }
                .background(ChartBackgroundStyle())
                .onTapGesture { location in
                    handleChartTap(location: location)
                }
                
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
    
    private func handleChartTap(location: CGPoint) {
        let chartWidth = CGFloat(sortedSteps.count) * 60
        let barWidth: CGFloat = 60
        let tappedIndex = Int(location.x / barWidth)
        
        if tappedIndex >= 0 && tappedIndex < sortedSteps.count {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                selectedDay = sortedSteps[tappedIndex]
                showingDayDetail = true
            }
        }
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
            
            // Second row: Notification stats
            HStack(spacing: 20) {
                VStack {
                    Text("\(totalNotifications)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(totalNotifications > 0 ? .orange : .green)
                    Text("Total Reminders")
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
                
                VStack {
                    Text(String(format: "%.1f", averageNotifications))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(averageNotifications > 1 ? .orange : .stepperLightTeal)
                    Text("Avg per Day")
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
                
                VStack {
                    Text("\(sortedSteps.filter { $0.inactivityNotifications == 0 }.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Active Days")
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
