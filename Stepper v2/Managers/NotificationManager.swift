import Foundation
import UserNotifications
import UIKit
import HealthKit

// MARK: - Notification Models
struct ActiveTimeRange: Identifiable, Codable {
    let id = UUID()
    var startTime: Date
    var endTime: Date
    
    var formattedRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    func contains(_ time: Date) -> Bool {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        let timeMinutes = (timeComponents.hour ?? 0) * 60 + (timeComponents.minute ?? 0)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        
        if startMinutes <= endMinutes {
            // Same day interval
            return timeMinutes >= startMinutes && timeMinutes <= endMinutes
        } else {
            // Spans midnight
            return timeMinutes >= startMinutes || timeMinutes <= endMinutes
        }
    }
}

// MARK: - Notification Timestamp Model
struct NotificationTimestamp: Codable {
    let date: Date
    let type: NotificationType
    
    enum NotificationType: String, Codable {
        case inactivity = "inactivity"
        case bedtime = "bedtime"
        case repeated = "repeated_inactivity"
    }
    
    var hour: Int {
        Calendar.current.component(.hour, from: date)
    }
    
    var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct NotificationSettings: Codable {
    // Bedtime notification
    var bedtimeNotificationEnabled: Bool = false
    var bedtimeHours: Int = 2
    var bedtimeMinutes: Int = 0
    var customBedtime: Date = {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 22
        components.minute = 30
        return calendar.date(from: components) ?? Date()
    }()
    
    // Inactivity notification
    var inactivityNotificationEnabled: Bool = false
    var inactivityDuration: Foundation.TimeInterval = 30 * 60 // 30 minutes in seconds
    var whitelistTimeIntervals: [ActiveTimeRange] = []
    
    // Helper computed properties
    var bedtimeOffsetMinutes: Int {
        return bedtimeHours * 60 + bedtimeMinutes
    }
    
    // Convenience computed properties for UI
    var inactivityMinutes: Int {
        get { Int(inactivityDuration / 60) }
        set { inactivityDuration = Foundation.TimeInterval(newValue * 60) }
    }
}

// MARK: - Enhanced Notification Manager with Hourly Tracking
class NotificationManager: ObservableObject {
    // MARK: - Published Properties
    @Published var settings = NotificationSettings()
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    
    // MARK: - Private Properties
    private let healthStore = HKHealthStore()
    private let userDefaults = UserDefaults.standard
    
    // UserDefaults Keys
    private let settingsKey = "NotificationSettings"
    private let lastActivityKey = "LastActivityTime"
    private let lastStepCountKey = "LastStepCount"
    private let lastNotificationKey = "LastInactivityNotification"
    private let dailyNotificationCountKey = "DailyInactivityNotificationCounts"
    private let lastCheckTimeKey = "LastInactivityCheck"
    
    // NEW: Hourly tracking keys
    private let notificationTimestampsKey = "NotificationTimestamps"
    private let hourlyNotificationCountsKey = "HourlyNotificationCounts"
    
    // State Variables
    private var lastStepCount: Int = 0
    private var lastActivityTime: Date = Date()
    private var lastNotificationTime: Date = Date.distantPast
    private var inactivityTimer: Timer?
    
    // NEW: In-memory cache for performance
    private var notificationTimestamps: [NotificationTimestamp] = []
    private var hourlyCountsCache: [String: [Int: Int]] = [:] // [dateKey: [hour: count]]
    
    // MARK: - Initializer
    init() {
        loadSettings()
        loadLastActivity()
        loadNotificationTimestamps()
        checkNotificationPermission()
        setupAppLifecycleNotifications()
        setupHealthKitBackgroundDelivery()
        cleanupOldNotificationData()
    }
    
    deinit {
        inactivityTimer?.invalidate()
    }
    
    // MARK: - Notification Timestamp Management
    
    /// Load notification timestamps from storage and build cache
    private func loadNotificationTimestamps() {
        if let data = userDefaults.data(forKey: notificationTimestampsKey),
           let timestamps = try? JSONDecoder().decode([NotificationTimestamp].self, from: data) {
            notificationTimestamps = timestamps
            buildHourlyCountsCache()
            print("📊 Loaded \(timestamps.count) notification timestamps")
        } else {
            notificationTimestamps = []
            hourlyCountsCache = [:]
        }
    }
    
    /// Save notification timestamps to persistent storage
    private func saveNotificationTimestamps() {
        if let encoded = try? JSONEncoder().encode(notificationTimestamps) {
            userDefaults.set(encoded, forKey: notificationTimestampsKey)
            buildHourlyCountsCache() // Rebuild cache after saving
            print("💾 Saved \(notificationTimestamps.count) notification timestamps")
        }
    }
    
    /// Build in-memory cache for fast hourly lookups
    private func buildHourlyCountsCache() {
        hourlyCountsCache.removeAll()
        
        for timestamp in notificationTimestamps {
            let dateKey = timestamp.dayKey
            let hour = timestamp.hour
            
            if hourlyCountsCache[dateKey] == nil {
                hourlyCountsCache[dateKey] = [:]
            }
            
            hourlyCountsCache[dateKey]![hour, default: 0] += 1
        }
        
        print("🔄 Built hourly cache for \(hourlyCountsCache.keys.count) days")
    }
    
    /// Record a new notification with precise timestamp
    private func recordNotificationTimestamp(_ type: NotificationTimestamp.NotificationType) {
        let timestamp = NotificationTimestamp(date: Date(), type: type)
        notificationTimestamps.append(timestamp)
        
        // Update cache immediately for real-time accuracy
        let dateKey = timestamp.dayKey
        let hour = timestamp.hour
        
        if hourlyCountsCache[dateKey] == nil {
            hourlyCountsCache[dateKey] = [:]
        }
        hourlyCountsCache[dateKey]![hour, default: 0] += 1
        
        saveNotificationTimestamps()
        
        print("📝 Recorded \(type.rawValue) notification at \(timestamp.date) (hour \(hour))")
    }
    
    /// Clean up old notification data (keep last 35 days)
    private func cleanupOldNotificationData() {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -35, to: Date()) ?? Date()
        
        let initialCount = notificationTimestamps.count
        notificationTimestamps = notificationTimestamps.filter { $0.date >= cutoffDate }
        
        if notificationTimestamps.count != initialCount {
            saveNotificationTimestamps()
            print("🧹 Cleaned up \(initialCount - notificationTimestamps.count) old notification timestamps")
        }
    }
    
    // MARK: - Public Hourly Tracking Methods
    
    /// Get notification count for a specific date and hour
    func getHourlyNotificationCount(for date: Date, hour: Int) -> Int {
        let calendar = Calendar.current
        let dateKey = dateToString(calendar.startOfDay(for: date))
        
        return hourlyCountsCache[dateKey]?[hour] ?? 0
    }
    
    /// Get all hourly notification counts for a specific date
    func getDailyHourlyNotificationCounts(for date: Date) -> [Int: Int] {
        let calendar = Calendar.current
        let dateKey = dateToString(calendar.startOfDay(for: date))
        
        return hourlyCountsCache[dateKey] ?? [:]
    }
    
    /// Get notification timestamps for a specific date (for detailed analysis)
    func getNotificationTimestamps(for date: Date) -> [NotificationTimestamp] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return notificationTimestamps.filter { timestamp in
            timestamp.date >= startOfDay && timestamp.date < endOfDay
        }
    }
    
    /// Get total notification count for a specific date (maintains backward compatibility)
    func getInactivityNotificationCount(for date: Date) -> Int {
        let hourlyData = getDailyHourlyNotificationCounts(for: date)
        return hourlyData.values.reduce(0, +)
    }
    
    // MARK: - Enhanced Notification Sending Methods
    
    private func sendInactivityNotification(actualInactivityTime: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Move! 👟"
        content.body = "You haven't moved in \(Int(actualInactivityTime / 60)) minutes. Let's get those steps in!"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.userInfo = [
            "type": "inactivity",
            "timestamp": Date().timeIntervalSince1970,
            "inactiveMinutes": Int(actualInactivityTime / 60)
        ]
        
        let request = UNNotificationRequest(
            identifier: "inactivity-alert-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("❌ Failed to send inactivity notification: \(error)")
            } else {
                print("✅ Sent inactivity notification (inactive for \(Int(actualInactivityTime / 60)) minutes)")
                
                // Record the notification timestamp
                self?.recordNotificationTimestamp(.inactivity)
                
                self?.updateAppBadge(increment: true)
                self?.lastNotificationTime = Date()
                self?.incrementDailyNotificationCount()
                self?.saveLastActivity()
            }
        }
    }
    
    private func scheduleRepeatingInactivityNotifications() {
        guard settings.inactivityNotificationEnabled else { return }
        
        print("📅 Scheduling repeating inactivity notifications every \(Int(settings.inactivityDuration / 60)) minutes")
        
        for i in 1...12 {
            let delay = settings.inactivityDuration * Double(i)
            
            let content = UNMutableNotificationContent()
            content.title = "Still Inactive! 👟"
            content.body = "You haven't moved in \(Int((settings.inactivityDuration * Double(i)) / 60)) minutes. Time to get those steps in!"
            content.sound = .default
            content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + i)
            content.userInfo = [
                "type": "repeated_inactivity",
                "interval": i,
                "scheduledFor": Date().addingTimeInterval(delay),
                "timestamp": Date().addingTimeInterval(delay).timeIntervalSince1970
            ]
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(
                identifier: "inactivity-repeat-\(i)-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { [weak self] error in
                if let error = error {
                    print("❌ Failed to schedule repeat inactivity notification \(i): \(error)")
                } else if i == 1 {
                    print("✅ Scheduled \(12) repeating inactivity notifications")
                    
                    // Pre-record the scheduled notifications (they'll be sent later)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay + 1) {
                        self?.recordNotificationTimestamp(.repeated)
                    }
                }
            }
        }
    }
    
    // MARK: - Bedtime Notifications with Tracking
    private func scheduleBedtimeNotification(currentSteps: Int, targetSteps: Int) {
        guard currentSteps < targetSteps else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["bedtime-reminder"])
            return
        }
        
        guard let bedtime = getBedtime() else {
            print("⚠️ No bedtime found")
            return
        }
        
        let stepsRemaining = targetSteps - currentSteps
        let notificationTime = Calendar.current.date(byAdding: .minute,
                                                   value: -settings.bedtimeOffsetMinutes,
                                                   to: bedtime)!
        
        guard notificationTime > Date() else {
            print("⚠️ Bedtime notification time has passed")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Stepper Reminder 🏃‍♀️"
        content.body = "You need \(stepsRemaining) more steps before bedtime in \(settings.bedtimeHours)h \(settings.bedtimeMinutes)m!"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.userInfo = [
            "type": "bedtime",
            "timestamp": notificationTime.timeIntervalSince1970,
            "stepsRemaining": stepsRemaining
        ]
        
        let triggerComponents = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(identifier: "bedtime-reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("❌ Failed to schedule bedtime notification: \(error)")
            } else {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                print("✅ Bedtime notification scheduled for \(formatter.string(from: notificationTime))")
                
                // Schedule recording of the bedtime notification when it fires
                let fireDelay = notificationTime.timeIntervalSince(Date())
                if fireDelay > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + fireDelay + 1) {
                        self?.recordNotificationTimestamp(.bedtime)
                    }
                }
            }
        }
    }
    
    // MARK: - Analytics and Insights Methods
    
    /// Get the most active notification hour across all days
    func getMostNotificationHour() -> Int? {
        var hourCounts: [Int: Int] = [:]
        
        for dayCounts in hourlyCountsCache.values {
            for (hour, count) in dayCounts {
                hourCounts[hour, default: 0] += count
            }
        }
        
        return hourCounts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Get notification pattern for specific hours across days
    func getNotificationPattern(for hour: Int, days: Int = 30) -> [Date: Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var pattern: [Date: Int] = [:]
        
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let count = getHourlyNotificationCount(for: date, hour: hour)
            if count > 0 {
                pattern[date] = count
            }
        }
        
        return pattern
    }
    
    /// Get average notifications per hour across all tracked days
    func getAverageHourlyNotifications() -> [Int: Double] {
        var hourTotals: [Int: Int] = [:]
        var hourDays: [Int: Int] = [:]
        
        for dayCounts in hourlyCountsCache.values {
            for hour in 0..<24 {
                let count = dayCounts[hour] ?? 0
                hourTotals[hour, default: 0] += count
                if count > 0 {
                    hourDays[hour, default: 0] += 1
                }
            }
        }
        
        var averages: [Int: Double] = [:]
        for hour in 0..<24 {
            let total = hourTotals[hour] ?? 0
            let days = max(hourDays[hour] ?? 0, 1)
            averages[hour] = Double(total) / Double(days)
        }
        
        return averages
    }
    
    // MARK: - All previous methods remain the same...
    // (Including HealthKit background delivery, app lifecycle, permission management, etc.)
    
    // MARK: - HealthKit Background Delivery
    private func setupHealthKitBackgroundDelivery() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { [weak self] success, error in
            if success {
                print("✅ HealthKit background delivery enabled")
                self?.setupHealthKitObserver()
            } else {
                print("❌ Failed to enable HealthKit background delivery: \(error?.localizedDescription ?? "Unknown")")
            }
        }
    }
    
    private func setupHealthKitObserver() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] query, completionHandler, error in
            
            if error != nil {
                print("❌ HealthKit observer error: \(error!.localizedDescription)")
                completionHandler()
                return
            }
            
            print("🩺 HealthKit detected step count change - app may be in background")
            
            DispatchQueue.main.async {
                self?.handleHealthKitUpdate()
            }
            
            completionHandler()
        }
        
        healthStore.execute(query)
        print("🔍 HealthKit observer query started")
    }
    
    private func handleHealthKitUpdate() {
        fetchLatestStepCount { [weak self] newStepCount in
            guard let self = self else { return }
            
            let previousStepCount = self.lastStepCount
            
            if newStepCount > previousStepCount {
                print("📈 Background step update: \(previousStepCount) → \(newStepCount)")
                
                self.lastActivityTime = Date()
                self.lastStepCount = newStepCount
                self.saveLastActivity()
                
                self.cancelPendingInactivityNotifications()
                self.scheduleNextInactivityCheck()
            }
        }
    }
    
    private func fetchLatestStepCount(completion: @escaping (Int) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            
            if let sum = result?.sumQuantity() {
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                completion(steps)
            } else {
                completion(0)
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - App Lifecycle Management
    private func setupAppLifecycleNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        print("📱 App became active - checking for missed activity and clearing badge")
        
        clearAppBadge()
        checkInactivityAfterAppOpen()
        setupInactivityTimer()
    }
    
    @objc private func appDidEnterBackground() {
        print("🌙 App entered background - maintaining badge count")
        // Don't clear badge when going to background - let it accumulate
    }
    
    @objc private func appWillTerminate() {
        print("💀 App will terminate - saving state")
        saveLastActivity()
        userDefaults.set(Date(), forKey: lastCheckTimeKey)
    }
    
    private func checkInactivityAfterAppOpen() {
        let lastCheck = userDefaults.object(forKey: lastCheckTimeKey) as? Date ?? lastActivityTime
        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        
        if timeSinceLastCheck > 300 { // 5+ minutes
            fetchLatestStepCount { [weak self] currentSteps in
                guard let self = self else { return }
                
                if currentSteps > self.lastStepCount {
                    print("📈 User was active while app was closed: \(self.lastStepCount) → \(currentSteps)")
                    self.lastActivityTime = Date()
                    self.lastStepCount = currentSteps
                    self.saveLastActivity()
                    
                    self.cancelPendingInactivityNotifications()
                } else {
                    self.checkAndSendInactivityNotification()
                }
                
                self.scheduleNextInactivityCheck()
            }
        }
    }
    
    // MARK: - Badge Management
    private func clearAppBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
            print("🔄 Cleared app badge")
        }
        
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("🗑️ Cleared delivered notifications from notification center")
    }
    
    private func updateAppBadge(increment: Bool = true) {
        DispatchQueue.main.async {
            if increment {
                UIApplication.shared.applicationIconBadgeNumber += 1
            } else {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
            print("🔢 App badge updated to: \(UIApplication.shared.applicationIconBadgeNumber)")
        }
    }
    
    func clearBadge() {
        clearAppBadge()
    }
    
    // MARK: - Inactivity Detection
    private func scheduleNextInactivityCheck() {
        cancelPendingInactivityNotifications()
        
        guard settings.inactivityNotificationEnabled else { return }
        
        let now = Date()
        let timeSinceLastActivity = now.timeIntervalSince(lastActivityTime)
        
        if timeSinceLastActivity >= settings.inactivityDuration {
            checkAndSendInactivityNotification()
            scheduleRepeatingInactivityNotifications()
        } else {
            let timeUntilInactive = settings.inactivityDuration - timeSinceLastActivity
            scheduleInactivityNotification(delay: timeUntilInactive)
        }
    }
    
    private func scheduleInactivityNotification(delay: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Move! 👟"
        content.body = "You haven't moved in \(Int(settings.inactivityDuration / 60)) minutes. Let's get those steps in!"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.userInfo = [
            "type": "first_inactivity",
            "scheduledFor": Date().addingTimeInterval(delay)
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: "inactivity-first-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("❌ Failed to schedule first inactivity notification: \(error)")
            } else {
                print("✅ Scheduled first inactivity check in \(Int(delay/60)) minutes")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 1) {
                    self?.scheduleRepeatingInactivityNotifications()
                }
            }
        }
    }
    
    private func checkAndSendInactivityNotification() {
        let now = Date()
        let timeSinceLastActivity = now.timeIntervalSince(lastActivityTime)
        let timeSinceLastNotification = now.timeIntervalSince(lastNotificationTime)
        
        guard timeSinceLastActivity >= settings.inactivityDuration else {
            print("📱 User became active recently, skipping inactivity notification")
            return
        }
        
        let minimumNotificationInterval: TimeInterval = 60 // 1 minute minimum
        guard timeSinceLastNotification >= minimumNotificationInterval else {
            print("🔕 Notification sent recently, preventing spam")
            return
        }
        
        let isWithinWhitelist = settings.whitelistTimeIntervals.contains { interval in
            interval.contains(now)
        }
        
        guard isWithinWhitelist else {
            print("⏰ Current time not in active hours, skipping inactivity notification")
            return
        }
        
        sendInactivityNotification(actualInactivityTime: timeSinceLastActivity)
    }
    
    private func cancelPendingInactivityNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let inactivityIdentifiers = requests
                .filter {
                    $0.identifier.hasPrefix("inactivity-") ||
                    $0.identifier.hasPrefix("periodic-check-")
                }
                .map { $0.identifier }
            
            if !inactivityIdentifiers.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: inactivityIdentifiers)
                print("🗑️ Cancelled \(inactivityIdentifiers.count) pending inactivity notifications")
            }
        }
    }
    
    // MARK: - Foreground Timer
    private func setupInactivityTimer() {
        inactivityTimer?.invalidate()
        
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkForInactivity()
        }
    }
    
    private func checkForInactivity() {
        guard settings.inactivityNotificationEnabled else { return }
        
        let now = Date()
        let timeSinceLastActivity = now.timeIntervalSince(lastActivityTime)
        
        guard timeSinceLastActivity >= settings.inactivityDuration else { return }
        
        let isWithinWhitelist = settings.whitelistTimeIntervals.contains { interval in
            interval.contains(now)
        }
        
        guard isWithinWhitelist else { return }
        
        sendInactivityNotification(actualInactivityTime: timeSinceLastActivity)
    }
    
    // MARK: - Daily Notification Tracking (Legacy - maintained for compatibility)
    private func incrementDailyNotificationCount() {
        let today = Calendar.current.startOfDay(for: Date())
        var counts = getDailyNotificationCounts()
        let todayKey = dateToString(today)
        counts[todayKey] = (counts[todayKey] ?? 0) + 1
        saveDailyNotificationCounts(counts)
        
        print("📊 Daily inactivity notifications for today: \(counts[todayKey] ?? 0)")
    }
    
    private func getDailyNotificationCounts() -> [String: Int] {
        guard let data = userDefaults.data(forKey: dailyNotificationCountKey),
              let counts = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return counts
    }
    
    private func saveDailyNotificationCounts(_ counts: [String: Int]) {
        if let encoded = try? JSONEncoder().encode(counts) {
            userDefaults.set(encoded, forKey: dailyNotificationCountKey)
        }
    }
    
    func getTodaysInactivityNotificationCount() -> Int {
        return getInactivityNotificationCount(for: Date())
    }
    
    private func dateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Storage & Settings
    private func saveLastActivity() {
        userDefaults.set(lastActivityTime, forKey: lastActivityKey)
        userDefaults.set(lastStepCount, forKey: lastStepCountKey)
        userDefaults.set(lastNotificationTime, forKey: lastNotificationKey)
    }
    
    private func loadLastActivity() {
        lastActivityTime = userDefaults.object(forKey: lastActivityKey) as? Date ?? Date()
        lastStepCount = userDefaults.integer(forKey: lastStepCountKey)
        lastNotificationTime = userDefaults.object(forKey: lastNotificationKey) as? Date ?? Date.distantPast
    }
    
    func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            settings = decoded
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
        scheduleNextInactivityCheck()
    }
    
    // MARK: - Permission Management
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.checkNotificationPermission()
            }
        }
    }
    
    // MARK: - Public Interface
    func updateStepCount(_ stepCount: Int, targetSteps: Int) {
        let previousStepCount = lastStepCount
        lastStepCount = stepCount
        
        if stepCount > previousStepCount {
            print("📈 User became active: \(previousStepCount) → \(stepCount) steps")
            
            lastActivityTime = Date()
            saveLastActivity()
            
            cancelPendingInactivityNotifications()
            scheduleNextInactivityCheck()
        }
        
        if settings.bedtimeNotificationEnabled {
            scheduleBedtimeNotification(currentSteps: stepCount, targetSteps: targetSteps)
        }
    }
    
    func scheduleNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🔄 Notifications rescheduled")
    }
    
    func addTimeInterval() {
        let now = Date()
        let calendar = Calendar.current
        
        var startComponents = calendar.dateComponents([.hour, .minute], from: now)
        startComponents.hour = 9
        startComponents.minute = 0
        
        var endComponents = calendar.dateComponents([.hour, .minute], from: now)
        endComponents.hour = 17
        endComponents.minute = 0
        
        let startTime = calendar.date(from: startComponents) ?? now
        let endTime = calendar.date(from: endComponents) ?? now
        
        let newInterval = ActiveTimeRange(startTime: startTime, endTime: endTime)
        settings.whitelistTimeIntervals.append(newInterval)
        saveSettings()
    }
    
    func removeTimeInterval(at index: Int) {
        guard index < settings.whitelistTimeIntervals.count else { return }
        settings.whitelistTimeIntervals.remove(at: index)
        saveSettings()
    }
    
    func updateTimeInterval(at index: Int, startTime: Date, endTime: Date) {
        guard index < settings.whitelistTimeIntervals.count else { return }
        settings.whitelistTimeIntervals[index].startTime = startTime
        settings.whitelistTimeIntervals[index].endTime = endTime
        saveSettings()
    }
    
    private func getBedtime() -> Date? {
        let calendar = Calendar.current
        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: settings.customBedtime)
        
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        todayComponents.hour = bedtimeComponents.hour
        todayComponents.minute = bedtimeComponents.minute
        
        guard let bedtime = calendar.date(from: todayComponents) else { return nil }
        
        if bedtime < Date() {
            return calendar.date(byAdding: .day, value: 1, to: bedtime)
        }
        
        return bedtime
    }
    
    // MARK: - Debug and Testing Methods
    
    /// Add a test notification for debugging (only in debug builds)
    #if DEBUG
    func addTestNotification(for date: Date, hour: Int, type: NotificationTimestamp.NotificationType = .inactivity) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = Int.random(in: 0...59)
        
        if let testDate = calendar.date(from: components) {
            let timestamp = NotificationTimestamp(date: testDate, type: type)
            notificationTimestamps.append(timestamp)
            saveNotificationTimestamps()
            print("🧪 Added test notification: \(timestamp.date) (hour \(hour))")
        }
    }
    
    /// Clear all notification data for testing
    func clearAllNotificationData() {
        notificationTimestamps.removeAll()
        hourlyCountsCache.removeAll()
        saveNotificationTimestamps()
        
        userDefaults.removeObject(forKey: dailyNotificationCountKey)
        print("🧹 Cleared all notification data for testing")
    }
    #endif
    
    func migrateExistingNotificationData() {
           let migrationKey = "HourlyNotificationMigrationComplete"
           
           // Check if migration has already been completed
           if UserDefaults.standard.bool(forKey: migrationKey) {
               print("✅ Hourly notification migration already completed")
               return
           }
           
           print("🔄 Starting migration of existing notification data...")
           
           // Get existing daily counts
           let existingCounts = getDailyNotificationCounts()
           
           if !existingCounts.isEmpty {
               print("📊 Found \(existingCounts.count) days of existing notification data to migrate")
               
               // Convert daily counts to mock hourly data
               for (dateString, count) in existingCounts {
                   if let date = stringToDate(dateString), count > 0 {
                       // Distribute notifications across typical work hours (9 AM - 5 PM)
                       let workHours = [9, 10, 11, 13, 14, 15, 16, 17] // Skip lunch hour (12)
                       let notificationsPerHour = max(1, count / workHours.count)
                       let remainingNotifications = count % workHours.count
                       
                       for (index, hour) in workHours.enumerated() {
                           let hourlyCount = notificationsPerHour + (index < remainingNotifications ? 1 : 0)
                           
                           // Create mock timestamps for this hour
                           for notificationIndex in 0..<hourlyCount {
                               let calendar = Calendar.current
                               var components = calendar.dateComponents([.year, .month, .day], from: date)
                               components.hour = hour
                               components.minute = Int.random(in: 0...59)
                               
                               if let mockDate = calendar.date(from: components) {
                                   let mockTimestamp = NotificationTimestamp(date: mockDate, type: .inactivity)
                                   notificationTimestamps.append(mockTimestamp)
                               }
                           }
                       }
                   }
               }
               
               // Save migrated data
               saveNotificationTimestamps()
               print("✅ Migration complete: converted \(existingCounts.values.reduce(0, +)) notifications to hourly format")
           } else {
               print("ℹ️ No existing notification data found to migrate")
           }
           
           // Mark migration as complete
           UserDefaults.standard.set(true, forKey: migrationKey)
           print("🎯 Hourly notification migration marked as complete")
       }
       
       /// Helper method to convert date string to Date
       private func stringToDate(_ dateString: String) -> Date? {
           let formatter = DateFormatter()
           formatter.dateFormat = "yyyy-MM-dd"
           return formatter.date(from: dateString)
       }
       
       /// Generate sample data for testing and demonstration
       func generateSampleNotificationData(days: Int = 30) {
           #if DEBUG
           print("🧪 Generating \(days) days of sample notification data...")
           
           let calendar = Calendar.current
           let today = calendar.startOfDay(for: Date())
           
           for dayOffset in 0..<days {
               guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
               
               // Simulate realistic notification patterns
               let isWeekend = calendar.component(.weekday, from: date) == 1 || calendar.component(.weekday, from: date) == 7
               let notificationProbability = isWeekend ? 0.1 : 0.3 // Less likely on weekends
               
               // Work hours where inactivity notifications are most likely
               let workHours = [9, 10, 11, 13, 14, 15, 16, 17]
               
               for hour in workHours {
                   if Double.random(in: 0...1) < notificationProbability {
                       // Add 1-2 notifications for this hour
                       let notificationCount = Int.random(in: 1...2)
                       
                       for _ in 0..<notificationCount {
                           var components = calendar.dateComponents([.year, .month, .day], from: date)
                           components.hour = hour
                           components.minute = Int.random(in: 0...59)
                           
                           if let notificationDate = calendar.date(from: components) {
                               let timestamp = NotificationTimestamp(date: notificationDate, type: .inactivity)
                               notificationTimestamps.append(timestamp)
                           }
                       }
                   }
               }
               
               // Occasional evening notifications (less frequent)
               let eveningHours = [18, 19, 20]
               for hour in eveningHours {
                   if Double.random(in: 0...1) < 0.1 { // 10% chance
                       var components = calendar.dateComponents([.year, .month, .day], from: date)
                       components.hour = hour
                       components.minute = Int.random(in: 0...59)
                       
                       if let notificationDate = calendar.date(from: components) {
                           let timestamp = NotificationTimestamp(date: notificationDate, type: .inactivity)
                           notificationTimestamps.append(timestamp)
                       }
                   }
               }
           }
           
           saveNotificationTimestamps()
           print("✅ Generated sample notification data for \(days) days")
           print("📊 Total notifications: \(notificationTimestamps.count)")
           #endif
       }
       
       /// Export notification data for debugging/analysis
       func exportNotificationData() -> String {
           var export = "Date,Hour,Type,Timestamp\n"
           
           let sortedTimestamps = notificationTimestamps.sorted { $0.date < $1.date }
           
           for timestamp in sortedTimestamps {
               let formatter = DateFormatter()
               formatter.dateFormat = "yyyy-MM-dd"
               let dateString = formatter.string(from: timestamp.date)
               
               formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
               let fullTimestamp = formatter.string(from: timestamp.date)
               
               export += "\(dateString),\(timestamp.hour),\(timestamp.type.rawValue),\(fullTimestamp)\n"
           }
           
           return export
       }
       
       /// Get statistics about notification data
       func getNotificationStatistics() -> [String: Any] {
           let totalNotifications = notificationTimestamps.count
           let uniqueDays = Set(notificationTimestamps.map { Calendar.current.startOfDay(for: $0.date) }).count
           
           var hourCounts: [Int: Int] = [:]
           var typeCounts: [String: Int] = [:]
           
           for timestamp in notificationTimestamps {
               hourCounts[timestamp.hour, default: 0] += 1
               typeCounts[timestamp.type.rawValue, default: 0] += 1
           }
           
           let mostActiveHour = hourCounts.max(by: { $0.value < $1.value })?.key ?? 0
           let averagePerDay = uniqueDays > 0 ? Double(totalNotifications) / Double(uniqueDays) : 0
           
           return [
               "totalNotifications": totalNotifications,
               "uniqueDays": uniqueDays,
               "averageNotificationsPerDay": averagePerDay,
               "mostActiveHour": mostActiveHour,
               "hourlyDistribution": hourCounts,
               "typeDistribution": typeCounts,
               "dataDateRange": getDataDateRange()
           ]
       }
       
       private func getDataDateRange() -> [String: String] {
           guard !notificationTimestamps.isEmpty else {
               return ["earliest": "No data", "latest": "No data"]
           }
           
           let sortedDates = notificationTimestamps.map(\.date).sorted()
           let formatter = DateFormatter()
           formatter.dateStyle = .medium
           
           return [
               "earliest": formatter.string(from: sortedDates.first!),
               "latest": formatter.string(from: sortedDates.last!)
           ]
       }
   }

