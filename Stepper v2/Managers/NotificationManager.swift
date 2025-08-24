import Foundation
import UserNotifications
import UIKit

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

// MARK: - Notification Manager
class NotificationManager: ObservableObject {
    @Published var settings = NotificationSettings()
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "NotificationSettings"
    private var lastStepCount: Int = 0
    private var lastActivityTime: Date = Date()
    private var inactivityTimer: Timer?
    
    init() {
        loadSettings()
        checkNotificationPermission()
        setupInactivityTimer()
    }
    
    deinit {
        inactivityTimer?.invalidate()
    }
    
    // MARK: - Settings Management
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
        
        // Reschedule notifications based on new settings
        scheduleNotifications()
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
                if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("❌ Notification permission denied")
                }
            }
        }
    }
    
    // MARK: - Step Tracking Updates
    func updateStepCount(_ stepCount: Int, targetSteps: Int) {
        let previousStepCount = lastStepCount
        lastStepCount = stepCount
        
        // If steps increased, update last activity time
        if stepCount > previousStepCount {
            lastActivityTime = Date()
            print("📈 Steps increased from \(previousStepCount) to \(stepCount)")
        }
        
        // Check if we should schedule bedtime notification
        if settings.bedtimeNotificationEnabled {
            scheduleBedtimeNotification(currentSteps: stepCount, targetSteps: targetSteps)
        }
    }
    
    // MARK: - Bedtime Notification
    private func scheduleBedtimeNotification(currentSteps: Int, targetSteps: Int) {
        guard currentSteps < targetSteps else {
            // Goal already achieved
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["bedtime-reminder"])
            return
        }
        
        guard let bedtime = getBedtime() else {
            print("⚠️ No bedtime found in Sleep schedule")
            return
        }
        
        let stepsRemaining = targetSteps - currentSteps
        let notificationTime = Calendar.current.date(byAdding: .minute,
                                                   value: -settings.bedtimeOffsetMinutes,
                                                   to: bedtime)!
        
        // Only schedule if notification time is in the future
        guard notificationTime > Date() else {
            print("⚠️ Bedtime notification time has passed")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Stepper Reminder 🏃‍♀️"
        content.body = "You need \(stepsRemaining) more steps before bedtime in \(settings.bedtimeHours)h \(settings.bedtimeMinutes)m!"
        content.sound = .default
        content.badge = 1
        
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
        
        // Create bedtime for today
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        todayComponents.hour = bedtimeComponents.hour
        todayComponents.minute = bedtimeComponents.minute
        
        guard let bedtime = calendar.date(from: todayComponents) else { return nil }
        
        // If bedtime has passed today, use tomorrow's bedtime
        if bedtime < Date() {
            return calendar.date(byAdding: .day, value: 1, to: bedtime)
        }
        
        return bedtime
    }
    
    // MARK: - Inactivity Notification
    private func setupInactivityTimer() {
        inactivityTimer?.invalidate()
        
        // Check every 5 minutes
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.checkForInactivity()
        }
    }
    
    private func checkForInactivity() {
        guard settings.inactivityNotificationEnabled else { return }
        guard notificationPermissionStatus == .authorized else { return }
        
        let now = Date()
        let timeSinceLastActivity = now.timeIntervalSince(lastActivityTime)
        
        // Check if inactivity time has passed since last activity
        guard timeSinceLastActivity >= settings.inactivityDuration else { return }
        
        // Check if current time is within whitelist intervals
        let isWithinWhitelist = settings.whitelistTimeIntervals.contains { interval in
            interval.contains(now)
        }
        
        guard isWithinWhitelist else { return }
        
        // Send inactivity notification
        sendInactivityNotification()
    }
    
    private func sendInactivityNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time to Move! 👟"
        content.body = "You haven't moved in \(Int(settings.inactivityDuration / 60)) minutes. Let's get those steps in!"
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(identifier: "inactivity-\(Date().timeIntervalSince1970)",
                                          content: content,
                                          trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send inactivity notification: \(error)")
            } else {
                print("✅ Inactivity notification sent")
            }
        }
    }
    
    // MARK: - Public Methods
    func scheduleNotifications() {
        // Remove all pending notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Reschedule based on current settings and step count
        // This will be called when settings change or step count updates
        print("🔄 Notifications rescheduled")
    }
    
    func addTimeInterval() {
        let now = Date()
        let calendar = Calendar.current
        
        // Default to 9 AM - 5 PM
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
}
