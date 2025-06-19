//
//  StepHistoryView.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//

import SwiftUI
import Charts

// MARK: - Step History View
struct StepHistoryView: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                
                Text("Step History")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            if healthManager.authorizationStatus == "Authorized" {
                if healthManager.weeklySteps.isEmpty {
                    VStack(spacing: 15) {
                        ProgressView("Loading history...")
                            .scaleEffect(1.2)
                        
                        Text("Fetching your step data")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 20) {
                        // Chart
                        Chart(healthManager.weeklySteps) { stepData in
                            BarMark(
                                x: .value("Day", stepData.dayName),
                                y: .value("Steps", stepData.steps)
                            )
                            .foregroundStyle(.blue.gradient)
                            .cornerRadius(4)
                        }
                        .frame(height: 250)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                        
                        // Stats
                        VStack(spacing: 15) {
                            Text("Last 7 Days")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 30) {
                                VStack {
                                    Text("\(healthManager.weeklySteps.map(\.steps).reduce(0, +))")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                    Text("Total")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    Text("\(healthManager.weeklySteps.map(\.steps).reduce(0, +) / max(healthManager.weeklySteps.count, 1))")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                    Text("Daily Avg")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    Text("\(healthManager.weeklySteps.map(\.steps).max() ?? 0)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                    Text("Best Day")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.1))
                        )
                        
                        // Refresh Button
                        Button(action: {
                            healthManager.fetchWeeklySteps()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh History")
                            }
                            .font(.headline)
                            .foregroundColor(.green)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green, lineWidth: 2)
                            )
                        }
                    }
                }
            } else {
                VStack(spacing: 15) {
                    Text("Health Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Enable Health access to view your step history.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        healthManager.requestHealthKitPermission()
                    }) {
                        Text("Enable Health Access")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}
