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

// MARK: - Notification Manager with HealthKit Background Delivery
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
    
    // State Variables
    private var lastStepCount: Int = 0
    private var lastActivityTime: Date = Date()
    private var lastNotificationTime: Date = Date.distantPast
    private var inactivityTimer: Timer?
    
    // MARK: - Initializer
    init() {
        loadSettings()
        loadLastActivity()
        checkNotificationPermission()
        setupAppLifecycleNotifications()
        setupHealthKitBackgroundDelivery()
    }
    
    deinit {
        inactivityTimer?.invalidate()
    }
    
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
                "scheduledFor": Date().addingTimeInterval(delay)
            ]
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(
                identifier: "inactivity-repeat-\(i)-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Failed to schedule repeat inactivity notification \(i): \(error)")
                } else if i == 1 {
                    print("✅ Scheduled \(12) repeating inactivity notifications")
                }
            }
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
    
    private func sendInactivityNotification(actualInactivityTime: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Move! 👟"
        content.body = "You haven't moved in \(Int(actualInactivityTime / 60)) minutes. Let's get those steps in!"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
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
                
                self?.updateAppBadge(increment: true)
                self?.lastNotificationTime = Date()
                self?.incrementDailyNotificationCount()
                self?.saveLastActivity()
            }
        }
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
    
    // MARK: - Daily Notification Tracking
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
    
    func getInactivityNotificationCount(for date: Date) -> Int {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let dateKey = dateToString(startOfDay)
        let counts = getDailyNotificationCounts()
        return counts[dateKey] ?? 0
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
    
    // MARK: - Bedtime Notifications
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
        
        let triggerComponents = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(identifier: "bedtime-reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule bedtime notification: \(error)")
            } else {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                print("✅ Bedtime notification scheduled for \(formatter.string(from: notificationTime))")
            }
        }
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
}
