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
            
            // Compact stats row
            HStack(spacing: 16) {
                // Steps
                VStack(spacing: 4) {
                    Text("\(stepData.steps)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.stepperYellow)
                    Text("steps")
                        .font(.caption2)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
                
                // Goal display instead of percentage
                VStack(spacing: 4) {
                    Text("\(stepData.targetSteps)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.stepperLightTeal)
                    Text("goal")
                        .font(.caption2)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
                
                // Average comparison
                VStack(spacing: 4) {
                    if isLoadingAverage {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .stepperCream))
                            .scaleEffect(0.6)
                    } else {
                        Text("\(weekdayAverage)")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.stepperCream)
                    }
                    Text("avg \(stepData.dayName)")
                        .font(.caption2)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
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
        .frame(maxWidth: 280)
        .offset(y: -180) // Position above the chart
        .onAppear {
            fetchWeekdayAverage()
        }
    }
    
    private func fetchWeekdayAverage() {
        healthManager.fetchWeekdayAverage(for: stepData.weekday) { average in
            DispatchQueue.main.async {
                self.weekdayAverage = average
                self.isLoadingAverage = false
            }
        }
    }
}
