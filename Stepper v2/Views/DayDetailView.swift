//
//  detail.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/22/25.
//
import SwiftUI
import Charts

// MARK: - Day Detail View

struct DayDetailOverlay: View {
    let stepData: StepData
    @ObservedObject var healthManager: HealthManager
    @Binding var isPresented: Bool
    @State private var weekdayAverage: Int = 0
    @State private var isLoadingAverage: Bool = true
    
    var body: some View {
        // Compact detail card positioned absolutely
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("\(stepData.dayName) • \(stepData.fullDate)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.stepperCream)
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
            }
            
            // Compact stats row with fixed widths to prevent jittering
            HStack(spacing: 16) {
                // Steps - fixed width
                VStack(spacing: 4) {
                    Text("\(stepData.steps)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.stepperYellow)
                        .monospacedDigit() // Ensures consistent digit spacing
                    Text("steps")
                        .font(.caption2)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
                .frame(width: 80) // Fixed width for steps section
                
                // Goal display - fixed width
                VStack(spacing: 4) {
                    Text("\(stepData.targetSteps)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.stepperLightTeal)
                        .monospacedDigit()
                    Text("goal")
                        .font(.caption2)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
                .frame(width: 80) // Fixed width for goal section
                
                // Average comparison - fixed width
                VStack(spacing: 4) {
                    if isLoadingAverage {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .stepperCream))
                            .scaleEffect(0.6)
                            .frame(height: 22) // Match text height
                    } else {
                        Text("\(weekdayAverage)")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.stepperCream)
                            .monospacedDigit()
                    }
                    Text("avg \(stepData.dayName)")
                        .font(.caption2)
                        .foregroundColor(.stepperCream.opacity(0.7))
                        .lineLimit(1) // Prevent text wrapping
                }
                .frame(width: 80) // Fixed width for average section
            }
            
            // Simple progress bar
            ProgressView(value: stepData.completionPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: stepData.targetMet ? .stepperYellow : .stepperLightTeal))
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                .background(Color.stepperCream.opacity(0.2))
                .cornerRadius(2)
            
            // Status text
            Text(stepData.targetMet ? "Goal achieved! 🎉" : "\(stepData.targetSteps - stepData.steps) steps to goal")
                .font(.caption)
                .foregroundColor(stepData.targetMet ? .stepperYellow : .stepperCream.opacity(0.8))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.stepperDarkBlue.opacity(0.95))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .frame(maxWidth: 340)
        .offset(y: -180) // Position above the chart
        .onAppear {
            fetchWeekdayAverage()
        }
        .onChange(of: stepData.id) { _ in
            // Reset state when stepData changes (new day selected)
            isLoadingAverage = true
            weekdayAverage = 0
            fetchWeekdayAverage()
        }
    }
    
    private func fetchWeekdayAverage() {
        print("🔍 Fetching average for \(stepData.dayName) (weekday: \(stepData.weekday))")
        
        healthManager.fetchWeekdayAverage(for: stepData.weekday) { [stepData] average in
            DispatchQueue.main.async {
                // Only update if this is still the same day being displayed
                if self.stepData.id == stepData.id {
                    print("✅ Setting average for \(stepData.dayName): \(average)")
                    self.weekdayAverage = average
                    self.isLoadingAverage = false
                } else {
                    print("⚠️ Ignoring stale average for \(stepData.dayName)")
                }
            }
        }
    }
}
