//
//  TodayStepView.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//

import SwiftUI

// MARK: - Today's Steps View
struct TodayStepsView: View {
    @ObservedObject var healthManager: HealthManager
    @State private var showingTargetSetting = false
    
    var targetManager: TargetManager {
        healthManager.getTargetManager()
    }
    
    var progressPercentage: Double {
        guard targetManager.currentTarget > 0 else { return 0 }
        return min(Double(healthManager.stepCount) / Double(targetManager.currentTarget), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Header with footprints
            VStack(spacing: 15) {
                HStack {
                    Text("Today's Steps")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.stepperCream)
                    
                }
                
                Text("Let's get those feet moving!")
                    .font(.subheadline)
                    .foregroundColor(.stepperCream.opacity(0.8))
            }
            

            
            Spacer()
            
            // Step Count Display
            if healthManager.authorizationStatus == "Authorized" {
                if healthManager.isLoading {
                    VStack(spacing: 15) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .stepperYellow))
                            .scaleEffect(1.5)
                        
                        Text("Counting your steps...")
                            .foregroundColor(.stepperCream.opacity(0.8))
                    }
                } else {
                    VStack(spacing: 20) {
                        // Main step count with paw theme
                        VStack(spacing: 15) {
                            HStack {
                                
                                Text("Steps Today")
                                    .font(.headline)
                                    .foregroundColor(.stepperCream.opacity(0.8))
                                
                                // Real-time indicator
                                if healthManager.isRealtimeActive {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 8, height: 8)
                                            .scaleEffect(healthManager.isRealtimeActive ? 1.0 : 0.5)
                                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: healthManager.isRealtimeActive)
                                        
                                        Text("LIVE")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            
                            Text("\(healthManager.stepCount)")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundColor(.stepperCream)
                                .animation(.easeInOut, value: healthManager.stepCount)
                            
                            Text("steps")
                                .font(.title2)
                                .foregroundColor(.stepperCream.opacity(0.7))
                        }
                        .padding(25)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.stepperCream.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.stepperYellow.opacity(0.3), lineWidth: 2)
                                )
                        )
                        
                        // Target and progress with cute styling
                        VStack(spacing: 15) {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Image(systemName: "target")
                                            .foregroundColor(.stepperYellow)
                                        Text("Today's Goal")
                                            .font(.headline)
                                            .foregroundColor(.stepperCream.opacity(0.8))
                                    }
                                    
                                    Text("\(targetManager.currentTarget) steps")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.stepperYellow)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showingTargetSetting = true
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.stepperYellow)
                                }
                            }
                            
                            // Cute progress bar
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Progress")
                                        .font(.subheadline)
                                        .foregroundColor(.stepperCream.opacity(0.7))
                                    
                                    Spacer()
                                    
                                    Text("\(Int(progressPercentage * 100))%")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(progressPercentage >= 1.0 ? .stepperYellow : .stepperCream)
                                }
                                
                                ProgressView(value: progressPercentage)
                                    .progressViewStyle(LinearProgressViewStyle(tint: progressPercentage >= 1.0 ? .stepperYellow : .stepperLightTeal))
                                    .scaleEffect(x: 1, y: 3, anchor: .center)
                                    .background(Color.stepperCream.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            
                            if progressPercentage >= 1.0 {
                                HStack {
                                    Image(systemName: "shoeprint.fill")
                                        .foregroundColor(.stepperYellow)
                                    Text("Awesome! Goal achieved! 🎉")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.stepperYellow)
                                    Image(systemName: "shoeprint.fill")
                                        .foregroundColor(.stepperYellow)
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
            } else {
                // Health Access Needed - same as history view
                VStack(spacing: 20) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.stepperYellow)
                    
                    Text("Health Access Needed")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.stepperCream)
                    
                    Text("Enable Health access to track your awesome steps!")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.stepperCream.opacity(0.8))
                    
                    Button(action: {
                        healthManager.requestHealthKitPermission()
                    }) {
                        Text("Enable Health Access 👣")
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
            
            Spacer()
            
//            // Refresh Button
//            if healthManager.authorizationStatus == "Authorized" {
//                Button(action: {
//                    healthManager.fetchTodaysSteps()
//                }) {
//                    HStack {
//                        Image(systemName: "arrow.clockwise")
//                        Text("Refresh Steps")
//                    }
//                    .font(.headline)
//                    .foregroundColor(.stepperYellow)
//                    .padding()
//                    .background(
//                        RoundedRectangle(cornerRadius: 12)
//                            .stroke(Color.stepperYellow, lineWidth: 2)
//                    )
//                }
//                .disabled(healthManager.isLoading)
//            }
        }
        .padding()
        .sheet(isPresented: $showingTargetSetting) {
            TargetSettingView(targetManager: targetManager, isPresented: $showingTargetSetting)
        }
    }
}
