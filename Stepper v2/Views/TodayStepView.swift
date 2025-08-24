import SwiftUI

// MARK: - Today's Steps View with Notification Tracking
struct TodayStepsView: View {
    @ObservedObject var healthManager: HealthManager
    @State private var showingTargetSetting = false
    @State private var todaysNotificationCount = 0
    
    var targetManager: TargetManager {
        healthManager.getTargetManager()
    }
    
    var notificationManager: NotificationManager? {
        healthManager.getNotificationManager()
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
            }
                        
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
                        // Main step count
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
                        
                        // Target and progress section
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
                            
                            // Progress bar
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
                        
                        // NEW: Inactivity Notifications Section
                        InactivityNotificationStatsView(
                            notificationCount: todaysNotificationCount,
                            isNotificationEnabled: notificationManager?.settings.inactivityNotificationEnabled ?? false
                        )
                    }
                }
            } else {
                // Health Access Needed
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
            
        }
        .padding()
        .sheet(isPresented: $showingTargetSetting) {
            TargetSettingView(targetManager: targetManager, isPresented: $showingTargetSetting)
        }
        .onAppear {
            updateNotificationCount()
        }
        .onChange(of: healthManager.stepCount) { _ in
            // Update notification count when steps change (might indicate app became active)
            updateNotificationCount()
        }
    }
    
    private func updateNotificationCount() {
        if let notificationManager = notificationManager {
            todaysNotificationCount = notificationManager.getTodaysInactivityNotificationCount()
        }
    }
}

// MARK: - Inactivity Notification Stats Component
struct InactivityNotificationStatsView: View {
    let notificationCount: Int
    let isNotificationEnabled: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.stepperYellow)
                Text("Nudges Today")
                    .font(.headline)
                    .foregroundColor(.stepperCream.opacity(0.8))
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(notificationCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(notificationCount > 0 ? .orange : .stepperLightTeal)
                    
                    Text(notificationCount == 1 ? "Reminder sent" : "Reminders sent")
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if !isNotificationEnabled {
                        Image(systemName: "bell.slash")
                            .font(.title2)
                            .foregroundColor(.stepperCream.opacity(0.5))
                        
                        Text("Disabled")
                            .font(.caption)
                            .foregroundColor(.stepperCream.opacity(0.5))
                    } else if notificationCount == 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("Great job!")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("Stay active")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.stepperCream.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            notificationCount > 0 ? Color.orange.opacity(0.3) :
                            (isNotificationEnabled ? Color.green.opacity(0.3) : Color.stepperCream.opacity(0.2)),
                            lineWidth: 1
                        )
                )
        )
    }
}
