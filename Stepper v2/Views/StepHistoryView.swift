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
                    StepHistoryContentView(weeklySteps: healthManager.weeklySteps, refreshAction: {
                        healthManager.fetchWeeklySteps()
                    })
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
                Image(systemName: "shoeprints.fill")
                    .font(.system(size: 25))
                    .foregroundColor(.stepperYellow)
                
                Text("Step History")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.stepperCream)
                
                Image(systemName: "shoeprints.fill")
                    .font(.system(size: 25))
                    .foregroundColor(.stepperYellow)
            }
            
            Text("Your awesome progress! 📈")
                .font(.subheadline)
                .foregroundColor(.stepperCream.opacity(0.8))
        }
    }
}

struct StepHistoryLoadingView: View {
    var body: some View {
        VStack(spacing: 15) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .stepperYellow))
                .scaleEffect(1.5)
            
            Text("Fetching your data...")
                .foregroundColor(.stepperCream.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StepHistoryContentView: View {
    let weeklySteps: [StepData]
    let refreshAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            StepHistoryChartView(weeklySteps: weeklySteps)
            StepHistoryLegendView()
            StepHistoryStatsView(weeklySteps: weeklySteps)
            StepHistoryRefreshButton(action: refreshAction)
        }
        .onAppear {
            // Refresh data when history view appears to ensure today's steps are current
            refreshAction()
        }
    }
}

struct StepHistoryChartView: View {
    let weeklySteps: [StepData]
    
    private var maxValue: Int {
        let maxSteps = weeklySteps.map(\.steps).max() ?? 0
        let maxTarget = weeklySteps.map(\.targetSteps).max() ?? 0
        return max(maxSteps, maxTarget)
    }
    
    private var chartMaxValue: Int {
        // 10% more than the maximum value
        return Int(Double(maxValue) * 1.1)
    }
    
    var body: some View {
        Chart(weeklySteps) { stepData in
            // Step bars
            BarMark(
                x: .value("Day", stepData.dayName),
                y: .value("Steps", stepData.steps)
            )
            .foregroundStyle(stepData.targetMet ? Color.stepperYellow : Color.stepperLightTeal)
            .cornerRadius(6)
            
            // Target circles
            PointMark(
                x: .value("Day", stepData.dayName),
                y: .value("Target", stepData.targetSteps)
            )
            .symbol(Circle())
            .symbolSize(120)
            .foregroundStyle(Color.stepperCream)
        }
        .chartYScale(domain: 0...chartMaxValue)
        .frame(height: 300)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.stepperCream.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.stepperYellow.opacity(0.3), lineWidth: 2)
                )
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
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "shoeprints.fill")
                    .foregroundColor(.stepperYellow)
                Text("Last 7 Days Summary")
                    .font(.headline)
                    .foregroundColor(.stepperCream)
                Image(systemName: "shoeprints.fill")
                    .foregroundColor(.stepperYellow)
            }
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(weeklySteps.map(\.steps).reduce(0, +))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.stepperYellow)
                    Text("Total Steps")
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
                
                VStack {
                    Text("\(weeklySteps.map(\.steps).reduce(0, +) / max(weeklySteps.count, 1))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.stepperLightTeal)
                    Text("Daily Average")
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
                
                VStack {
                    Text("\(weeklySteps.filter(\.targetMet).count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.stepperCream)
                    Text("Goals Met")
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.7))
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

struct StepHistoryRefreshButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Refresh History")
            }
            .font(.headline)
            .foregroundColor(.stepperYellow)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.stepperYellow, lineWidth: 2)
            )
        }
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
            
            Text("Enable Health access to see your paw-some step history!")
                .multilineTextAlignment(.center)
                .foregroundColor(.stepperCream.opacity(0.8))
            
            Button(action: requestPermission) {
                Text("Enable Health Access 🐾")
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
