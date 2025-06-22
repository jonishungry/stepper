//
//  TargetManager.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//

import Foundation

// MARK: - Target Manager
class TargetManager: ObservableObject {
    @Published var currentTarget: Int = 10000
    
    private let userDefaults = UserDefaults.standard
    private let currentTargetKey = "currentStepTarget"
    private let targetHistoryKey = "targetHistory"
    
    init() {
        loadCurrentTarget()
    }
    
    func saveTarget(_ target: Int) {
        currentTarget = target
        userDefaults.set(target, forKey: currentTargetKey)
        
        // Save target for today's date specifically
        let today = Calendar.current.startOfDay(for: Date())
        saveTargetForDate(target, date: today)
    }
    
    func saveTargetForSpecificDate(_ target: Int, date: Date) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        saveTargetForDate(target, date: startOfDay)
        
        // If setting for today, also update current target
        let today = Calendar.current.startOfDay(for: Date())
        if startOfDay == today {
            currentTarget = target
            userDefaults.set(target, forKey: currentTargetKey)
        }
    }
    
    private func loadCurrentTarget() {
        // First try to get today's specific target
        let today = Calendar.current.startOfDay(for: Date())
        if let todaysTarget = getStoredTargetForDate(today) {
            currentTarget = todaysTarget
        } else {
            // Fall back to general current target
            let saved = userDefaults.integer(forKey: currentTargetKey)
            currentTarget = saved > 0 ? saved : 10000
        }
    }
    
    private func saveTargetForDate(_ target: Int, date: Date) {
        var targetHistory = getTargetHistory()
        let dateKey = dateToString(date)
        targetHistory[dateKey] = target
        
        if let data = try? JSONEncoder().encode(targetHistory) {
            userDefaults.set(data, forKey: targetHistoryKey)
        }
    }
    
    private func getStoredTargetForDate(_ date: Date) -> Int? {
        let targetHistory = getTargetHistory()
        let dateKey = dateToString(date)
        return targetHistory[dateKey]
    }
    
    func getTargetForDate(_ date: Date) -> Int {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        
        // First check if this specific date has a stored target
        if let specificTarget = getStoredTargetForDate(startDate) {
            return specificTarget
        }
        
        // If no specific target for this date, find the most recent target before this date
        let targetHistory = getTargetHistory()
        let sortedDates = targetHistory.keys.compactMap { stringToDate($0) }
            .filter { $0 <= startDate }
            .sorted()
        
        if let mostRecentDate = sortedDates.last {
            let mostRecentKey = dateToString(mostRecentDate)
            return targetHistory[mostRecentKey] ?? currentTarget
        }
        
        // If no historical targets, use current target
        return currentTarget
    }
    
    func getAllStoredTargets() -> [Date: Int] {
        let targetHistory = getTargetHistory()
        var result: [Date: Int] = [:]
        
        for (dateString, target) in targetHistory {
            if let date = stringToDate(dateString) {
                result[date] = target
            }
        }
        
        return result
    }
    
    func hasSpecificTargetForDate(_ date: Date) -> Bool {
        let startDate = Calendar.current.startOfDay(for: date)
        return getStoredTargetForDate(startDate) != nil
    }
    
    private func getTargetHistory() -> [String: Int] {
        guard let data = userDefaults.data(forKey: targetHistoryKey),
              let history = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return history
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
