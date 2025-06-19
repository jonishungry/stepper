//
//  TodayStepView.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//

import SwiftUI

struct TodayStepsView: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Today's Steps")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            // Step Count Display
            VStack(spacing: 20) {
                if healthManager.authorizationStatus == "Authorized" {
                    if healthManager.isLoading {
                        ProgressView("Loading steps...")
                            .scaleEffect(1.2)
                    } else {
                        VStack(spacing: 10) {
                            Text("Current Count")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("\(healthManager.stepCount)")
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .animation(.easeInOut, value: healthManager.stepCount)
                            
                            Text("steps")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                } else if healthManager.authorizationStatus == "Not Determined" {
                    VStack(spacing: 15) {
                        Text("Health Access Required")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("This app needs access to your Health data to show your step count.")
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
                } else if healthManager.authorizationStatus == "Denied" {
                    VStack(spacing: 15) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("Health Access Denied")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Please enable Health access in Settings to view your steps.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }) {
                            Text("Open Settings")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            
            Spacer()
            
            // Refresh Button
            if healthManager.authorizationStatus == "Authorized" {
                Button(action: {
                    healthManager.fetchTodaysSteps()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Steps")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                }
                .disabled(healthManager.isLoading)
            }
        }
        .padding()
    }
}
