//
//  GoalAchievementManager.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 9/1/25.
//
import SwiftUI

// MARK: - Goal Achievement Manager
class GoalAchievementManager: ObservableObject {
    @Published var shouldShowCelebration = false
    
    private let userDefaults = UserDefaults.standard
    private let lastCelebrationKey = "LastGoalCelebrationDate"
    private let achievementDatesKey = "GoalAchievementDates"
    
    /// Check if we should show celebration for today's goal achievement
    func checkForGoalAchievement(currentSteps: Int, targetSteps: Int) {
        guard currentSteps >= targetSteps else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        let lastCelebrationDate = userDefaults.object(forKey: lastCelebrationKey) as? Date
        
        // Only show celebration once per day
        if let lastDate = lastCelebrationDate,
           Calendar.current.isDate(lastDate, inSameDayAs: today) {
            return
        }
        
        // Record this achievement
        recordGoalAchievement(for: today)
        
        // Show celebration
        DispatchQueue.main.async {
            self.shouldShowCelebration = true
        }
        
        // Update last celebration date
        userDefaults.set(today, forKey: lastCelebrationKey)
        
        print("🎉 Triggering goal celebration for \(currentSteps) steps (target: \(targetSteps))")
    }
    
    /// Record goal achievement for streak tracking
    private func recordGoalAchievement(for date: Date) {
        var achievementDates = getAchievementDates()
        let dateKey = dateToString(date)
        achievementDates.insert(dateKey)
        
        // Keep only last 365 days
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        achievementDates = achievementDates.filter { dateString in
            if let date = stringToDate(dateString) {
                return date >= oneYearAgo
            }
            return false
        }
        
        saveAchievementDates(achievementDates)
    }
    
    /// Get current goal streak
    func getCurrentStreak() -> Int {
        let achievementDates = getAchievementDates()
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        while achievementDates.contains(dateToString(currentDate)) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        return streak
    }
    
    /// Get total goal achievements in the last 30 days
    func getRecentAchievements() -> Int {
        let achievementDates = getAchievementDates()
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        
        return achievementDates.filter { dateString in
            if let date = stringToDate(dateString) {
                return date >= thirtyDaysAgo
            }
            return false
        }.count
    }
    
    // MARK: - Private Storage Methods
    private func getAchievementDates() -> Set<String> {
        if let data = userDefaults.data(forKey: achievementDatesKey),
           let dates = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return dates
        }
        return Set<String>()
    }
    
    private func saveAchievementDates(_ dates: Set<String>) {
        if let encoded = try? JSONEncoder().encode(dates) {
            userDefaults.set(encoded, forKey: achievementDatesKey)
        }
    }
    
    private func dateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func stringToDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
