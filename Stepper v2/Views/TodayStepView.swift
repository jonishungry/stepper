// Updated TodayStepsView with Goal Celebration Integration

import SwiftUI

// Add these new properties and methods to TodayStepsView:

struct TodayStepsView: View {
    @ObservedObject var healthManager: HealthManager
    @State private var showingTargetSetting = false
    @State private var todaysNotificationCount = 0
    
    // NEW: Goal celebration state
    @StateObject private var goalAchievementManager = GoalAchievementManager()
    @State private var hasCheckedGoalToday = false
    
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
            // Header with footprints and streak info
            VStack(spacing: 15) {
                HStack {
                    Text("Today's Steps")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.stepperCream)
                }
                
                // NEW: Goal streak display
                if goalAchievementManager.getCurrentStreak() > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(goalAchievementManager.getCurrentStreak()) day streak!")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                            )
                    )
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
                        
//                        // Inactivity Notifications Section
//                        InactivityNotificationStatsView(
//                            notificationCount: todaysNotificationCount,
//                            isNotificationEnabled: notificationManager?.settings.inactivityNotificationEnabled ?? false
//                        )
                        
                        // NEW: Recent achievements summary
                        RecentAchievementsSummaryView(goalAchievementManager: goalAchievementManager)
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
        // NEW: Goal celebration overlay
        .fullScreenCover(isPresented: $goalAchievementManager.shouldShowCelebration) {
            GoalCelebrationView(
                stepCount: healthManager.stepCount,
                targetSteps: targetManager.currentTarget,
                isPresented: $goalAchievementManager.shouldShowCelebration
            )
        }
        .onAppear {
            updateNotificationCount()
        }
        .onChange(of: healthManager.stepCount) { newStepCount in
            updateNotificationCount()
            
            // NEW: Check for goal achievement
            if !hasCheckedGoalToday {
                goalAchievementManager.checkForGoalAchievement(
                    currentSteps: newStepCount,
                    targetSteps: targetManager.currentTarget
                )
                
                // Only check once per app session
                if newStepCount >= targetManager.currentTarget {
                    hasCheckedGoalToday = true
                }
            }
        }
        // NEW: Reset goal check when app becomes active (new day or app restart)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            let today = Calendar.current.startOfDay(for: Date())
            let lastCheck = UserDefaults.standard.object(forKey: "LastGoalCheckDate") as? Date
            
            if let lastCheck = lastCheck,
               !Calendar.current.isDate(lastCheck, inSameDayAs: today) {
                hasCheckedGoalToday = false
                UserDefaults.standard.set(today, forKey: "LastGoalCheckDate")
            } else if lastCheck == nil {
                hasCheckedGoalToday = false
                UserDefaults.standard.set(today, forKey: "LastGoalCheckDate")
            }
        }
    }
    
    private func updateNotificationCount() {
        if let notificationManager = notificationManager {
            todaysNotificationCount = notificationManager.getTodaysInactivityNotificationCount()
        }
    }
}

// MARK: - NEW: Recent Achievements Summary View
struct RecentAchievementsSummaryView: View {
    @ObservedObject var goalAchievementManager: GoalAchievementManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.stepperYellow)
                Text("Recent Achievements")
                    .font(.headline)
                    .foregroundColor(.stepperCream.opacity(0.8))
                Spacer()
            }
            
            HStack(spacing: 30) {
                VStack(alignment: .center, spacing: 4) {
                    Text("\(goalAchievementManager.getCurrentStreak())")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    
                    Text("Day Streak")
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
                
                VStack(alignment: .center, spacing: 4) {
                    Text("\(goalAchievementManager.getRecentAchievements())")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    Text("Goals This Month")
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
                
                VStack(alignment: .center, spacing: 4) {
                    let percentage = min(100, Int((Double(goalAchievementManager.getRecentAchievements()) / 30.0) * 100))
                    Text("\(percentage)%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.stepperYellow)
                    
                    Text("Success Rate")
                        .font(.caption)
                        .foregroundColor(.stepperCream.opacity(0.7))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.stepperCream.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.stepperYellow.opacity(0.2), lineWidth: 1)
                )
        )
    }
}


