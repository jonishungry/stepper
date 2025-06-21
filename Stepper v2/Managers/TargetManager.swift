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
        
        // Save target for today's date
        let today = Calendar.current.startOfDay(for: Date())
        saveTargetForDate(target, date: today)
    }
    
    private func loadCurrentTarget() {
        let saved = userDefaults.integer(forKey: currentTargetKey)
        currentTarget = saved > 0 ? saved : 10000
    }
    
    private func saveTargetForDate(_ target: Int, date: Date) {
        var targetHistory = getTargetHistory()
        let dateKey = dateToString(date)
        targetHistory[dateKey] = target
        
        if let data = try? JSONEncoder().encode(targetHistory) {
            userDefaults.set(data, forKey: targetHistoryKey)
        }
    }
    
    func getTargetForDate(_ date: Date) -> Int {
        let targetHistory = getTargetHistory()
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        
        // Look for exact date first
        let dateKey = dateToString(startDate)
        if let target = targetHistory[dateKey] {
            return target
        }
        
        // If no exact date, find the most recent target before this date
        let sortedDates = targetHistory.keys.compactMap { stringToDate($0) }
            .filter { $0 <= startDate }
            .sorted()
        
        if let mostRecentDate = sortedDates.last {
            let mostRecentKey = dateToString(mostRecentDate)
            return targetHistory[mostRecentKey] ?? currentTarget
        }
        
        return currentTarget
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
