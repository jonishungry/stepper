//
//  detail.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/22/25.
//
import SwiftUI
import Charts

// MARK: - Day Detail View
struct DayDetailView: View {
    let stepData: StepData
    @ObservedObject var healthManager: HealthManager
    @Environment(\.dismiss) private var dismiss
    
    private var weekdayAverage: Int {
        return healthManager.getWeekdayAverage(for: stepData.weekday)
    }
    
    private var progressText: String {
        if stepData.targetMet {
            return "Goal achieved! 🎉"
        } else {
            let remaining = stepData.targetSteps - stepData.steps
            return "\(remaining) steps to go"
        }
    }
    
    private var comparisonText: String {
        if weekdayAverage == 0 {
            return "First recorded \(stepData.weekdayName)"
        } else if stepData.steps > weekdayAverage {
            let difference = stepData.steps - weekdayAverage
            return "\(difference) steps above your \(stepData.weekdayName) average"
        } else if stepData.steps < weekdayAverage {
            let difference = weekdayAverage - stepData.steps
            return "\(difference) steps below your \(stepData.weekdayName) average"
        } else {
            return "Right on your \(stepData.weekdayName) average!"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.stepperDarkBlue, Color.stepperTeal]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Text(stepData.weekdayName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.stepperCream)
                        
                        Text(stepData.fullDate)
                            .font(.title2)
                            .foregroundColor(.stepperCream.opacity(0.8))
                    }
                    
                    // Main Stats
                    VStack(spacing: 25) {
                        // Steps Count
                        VStack(spacing: 15) {
                            HStack {
                                Image(systemName: "shoeprints.fill")
                                    .font(.title2)
                                    .foregroundColor(.stepperYellow)
                                Text("Steps Taken")
                                    .font(.headline)
                                    .foregroundColor(.stepperCream.opacity(0.8))
                            }
                            
                            Text("\(stepData.steps)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.stepperYellow)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.stepperCream.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.stepperYellow.opacity(0.3), lineWidth: 2)
                                )
                        )
                        
                        // Goal Progress
                        VStack(spacing: 15) {
                            HStack {
                                Image(systemName: "target")
                                    .font(.title2)
                                    .foregroundColor(.stepperLightTeal)
                                Text("Goal: \(stepData.targetSteps)")
                                    .font(.headline)
                                    .foregroundColor(.stepperCream.opacity(0.8))
                            }
                            
                            // Progress Bar
                            VStack(spacing: 8) {
                                ProgressView(value: stepData.completionPercentage)
                                    .progressViewStyle(LinearProgressViewStyle(tint: stepData.targetMet ? .stepperYellow : .stepperLightTeal))
                                    .scaleEffect(x: 1, y: 3, anchor: .center)
                                    .background(Color.stepperCream.opacity(0.2))
                                    .cornerRadius(4)
                                
                                Text(progressText)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(stepData.targetMet ? .stepperYellow : .stepperLightTeal)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.stepperTeal.opacity(0.3))
                        )
                        
                        // Weekday Comparison - only show if we have historical data
                        VStack(spacing: 15) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.title2)
                                    .foregroundColor(.stepperCream)
                                Text("\(stepData.weekdayName) Average")
                                    .font(.headline)
                                    .foregroundColor(.stepperCream.opacity(0.8))
                            }
                            
                            Text("\(weekdayAverage) steps")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.stepperCream)
                            
                            Text(comparisonText)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.stepperCream.opacity(0.8))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.stepperCream.opacity(0.1))
                        )
                        
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Day Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.stepperCream)
                }
            }
        }
    }
}
