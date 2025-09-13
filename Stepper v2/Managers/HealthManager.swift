//
//  HealthManager.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//

import CoreData
import CoreMotion
import SwiftUI
import HealthKit

// MARK: - Health Manager
class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private let pedometer = CMPedometer()
    @Published var stepCount: Int = 0
    @Published var weeklySteps: [StepData] = []
    @Published var isLoading: Bool = false
    @Published var authorizationStatus: String = "Not Determined"
    @Published var isRealtimeActive: Bool = false
    
    private let targetManager = TargetManager()
    private var notificationManager: NotificationManager?

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var refreshTimer: Timer?
    private var stepQuery: HKQuery?
    private var loadingTimer: Timer?
    private var baselineSteps: Int = 0
    private var context: NSManagedObjectContext?
    private let authorizationKey = "HealthKitAuthorizationGranted"

    
    init() {
        checkAuthorizationStatus()
        setupNotifications()
        checkPedometerAvailability()
    }
    
    deinit {
        stopRefreshTimer()
        stopLoadingTimer()
        stopRealtimeUpdates()
        if let query = stepQuery {
            healthStore.stop(query)
        }
    }
    
    
    // MARK: - Core Data Methods
    func setContext(_ context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Notification Manager Integration
    func setNotificationManager(_ manager: NotificationManager) {
        self.notificationManager = manager
    }
    
    private func updateNotificationManager() {
        guard let notificationManager = notificationManager else { return }
        
        let today = Date()
        let todaysTarget = targetManager.getTargetForDate(today)
        notificationManager.updateStepCount(stepCount, targetSteps: todaysTarget)
    }
    
    func getNotificationManager() -> NotificationManager? {
        return notificationManager
    }
    
    private func saveStepData(_ steps: Int, for date: Date, target: Int) {
        guard let context = context else {
            print("⚠️ Core Data context not available - skipping save")
            return
        }
        
        DispatchQueue.main.async {
            let entity = StepHistoryEntity.fetchOrCreate(for: date, in: context)
            entity.steps = Int32(steps)
            entity.targetSteps = Int32(target)
            
            do {
                try context.save()
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                print("💾 Saved: \(steps) steps for \(formatter.string(from: date))")
            } catch {
                print("❌ Core Data save failed: \(error.localizedDescription)")
            }
        }
    }
    
    func getWeekdayAverage(for weekday: Int) -> Int {
        guard let context = context else { return 0 }
        return StepHistoryEntity.averageStepsForWeekday(weekday, in: context)
    }
    
    // MARK: - Public Methods
    func getTargetManager() -> TargetManager {
        return targetManager
    }
    
    private func checkPedometerAvailability() {
        if CMPedometer.isStepCountingAvailable() {
            print("📱 CMPedometer available - real-time updates enabled")
        } else {
            print("❌ CMPedometer not available - using HealthKit only")
        }
    }
    
    private func setupNotifications() {
        // Start real-time when app becomes active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Stop real-time when app goes to background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        if authorizationStatus == "Authorized" {
            startHybridTracking()
        }
    }
    
    @objc private func appDidEnterBackground() {
        stopRealtimeUpdates()
        stopRefreshTimer()
        stopLoadingTimer()
        // Sync current data to HealthKit baseline
        syncToHealthKitBaseline()
    }
    
    // MARK: - Hybrid Tracking Methods
    private func startHybridTracking() {
        print("🚀 Starting hybrid tracking (HealthKit + CMPedometer)")
        
        // First get current HealthKit data as baseline
        fetchHealthKitBaseline { [weak self] in
            // Then start real-time updates on top of baseline
            self?.startRealtimeUpdates()
            // Keep HealthKit timer as backup
            self?.startRefreshTimer()
        }
    }
    
    private func fetchHealthKitBaseline(completion: @escaping () -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, error in
            DispatchQueue.main.async {
                if let sum = result?.sumQuantity() {
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    self?.baselineSteps = steps
                    self?.stepCount = steps
                    print("📊 HealthKit baseline: \(steps) steps")
                } else {
                    self?.baselineSteps = 0
                    self?.stepCount = 0
                    print("📊 HealthKit baseline: 0 steps")
                }
                completion()
            }
        }
        
        healthStore.execute(query)
    }
    
    private func startRealtimeUpdates() {
        guard CMPedometer.isStepCountingAvailable() else {
            print("❌ Real-time updates not available")
            return
        }
        
        stopRealtimeUpdates() // Stop any existing updates
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        print("⚡ Starting real-time CMPedometer updates")
        isRealtimeActive = true
        
        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ CMPedometer error: \(error.localizedDescription)")
                    return
                }
                
                if let data = data {
                    let realtimeSteps = data.numberOfSteps.intValue
                    
                    // Use real-time data as it's more current than HealthKit
                    let previousSteps = self?.stepCount ?? 0
                    
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self?.stepCount = realtimeSteps
                    }
                    
                    if realtimeSteps != previousSteps {
                        print("⚡ Real-time update: \(previousSteps) → \(realtimeSteps) steps")
                    }
                }
            }
        }
    }
    
    private func stopRealtimeUpdates() {
        if isRealtimeActive {
            print("⏹️ Stopping real-time updates")
            pedometer.stopUpdates()
            isRealtimeActive = false
        }
    }
    
    private func syncToHealthKitBaseline() {
        // When going to background, update our baseline for next time
        fetchHealthKitBaseline { }
    }
    
    // MARK: - Timer Methods
    private func startRefreshTimer() {
        stopRefreshTimer()
        
        print("🔄 Starting 15-second HealthKit backup timer")
        // Backup timer - less frequent since real-time is handling foreground
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] timer in
            // Only use HealthKit timer if real-time isn't active
            if !(self?.isRealtimeActive ?? false) {
                print("⏰ Backup timer - fetching HealthKit data")
                self?.fetchTodaysSteps()
            }
        }
    }
    
    private func stopRefreshTimer() {
        if refreshTimer != nil {
            print("⏹️ Stopping refresh timer")
        }
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func startLoadingTimer() {
        stopLoadingTimer()
        
        // Only show loading after 5 seconds
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isLoading = true
                print("⏳ Showing loading indicator after 5 second delay")
            }
        }
    }
    
    private func stopLoadingTimer() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        isLoading = false
    }
    
    // MARK: - HealthKit Permission Methods
    func requestHealthKitPermission() {
            guard HKHealthStore.isHealthDataAvailable() else {
                DispatchQueue.main.async {
                    self.authorizationStatus = "Health data not available"
                }
                return
            }
            
            print("🔐 Requesting HealthKit permission...")
            
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let typesToRead: Set<HKObjectType> = [stepType]
            
            healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ HealthKit authorization error: \(error.localizedDescription)")
                        self?.authorizationStatus = "Error"
                        return
                    }
                    
                    if success {
                        print("✅ HealthKit authorization request completed - testing access...")
                        
                        // Always test actual access after permission request
                        self?.testHealthKitAccess { hasAccess in
                            if hasAccess {
                                UserDefaults.standard.set(true, forKey: self?.authorizationKey ?? "")
                                self?.authorizationStatus = "Authorized"
                                print("✅ HealthKit access confirmed after permission request")
                                
                                // Start tracking immediately
                                self?.startHybridTracking()
                                self?.fetchWeeklySteps()
                                self?.setupLiveQuery()
                            } else {
                                UserDefaults.standard.set(false, forKey: self?.authorizationKey ?? "")
                                self?.authorizationStatus = "Denied"
                                print("❌ HealthKit access still denied after permission request")
                            }
                        }
                    } else {
                        UserDefaults.standard.set(false, forKey: self?.authorizationKey ?? "")
                        self?.authorizationStatus = "Denied"
                        print("❌ HealthKit authorization request failed")
                    }
                }
            }
        }
     
    func checkAuthorizationStatus() {
            guard HKHealthStore.isHealthDataAvailable() else {
                DispatchQueue.main.async {
                    self.authorizationStatus = "Health data not available"
                }
                return
            }
            
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            
            // First check the system authorization status
            let systemStatus = healthStore.authorizationStatus(for: stepType)
            
            print("🔐 System HealthKit status: \(systemStatus.rawValue)")
            
            switch systemStatus {
            case .notDetermined:
                DispatchQueue.main.async {
                    self.authorizationStatus = "Not Determined"
                    print("🔐 HealthKit status: Not Determined")
                }
                
            case .sharingDenied:
                // Clear any stored authorization since it's definitely denied
                UserDefaults.standard.set(false, forKey: authorizationKey)
                DispatchQueue.main.async {
                    self.authorizationStatus = "Denied"
                    print("❌ HealthKit status: Definitively Denied")
                }
                
            case .sharingAuthorized:
                // System says authorized, but let's verify with actual data access
                print("✅ System reports authorized - testing actual access...")
                testHealthKitAccess { [weak self] hasAccess in
                    if hasAccess {
                        UserDefaults.standard.set(true, forKey: self?.authorizationKey ?? "")
                        self?.authorizationStatus = "Authorized"
                        print("✅ HealthKit access confirmed - Starting tracking")
                        
                        // Only start tracking if not already active
                        if !(self?.isRealtimeActive ?? false) && self?.authorizationStatus == "Authorized" {
                            self?.startHybridTracking()
                            self?.fetchWeeklySteps()
                            self?.setupLiveQuery()
                        }
                    } else {
                        // System says authorized but we can't actually access data
                        // This happens sometimes - try one more permission request
                        print("⚠️ System authorized but access test failed - may need re-permission")
                        UserDefaults.standard.set(false, forKey: self?.authorizationKey ?? "")
                        self?.authorizationStatus = "Not Determined"
                    }
                }
                
            @unknown default:
                DispatchQueue.main.async {
                    self.authorizationStatus = "Unknown"
                    print("⚠️ HealthKit status: Unknown")
                }
            }
        }
    
    private func setupLiveQuery() {
            // Don't setup multiple queries
            if stepQuery != nil {
                print("🔍 Live query already exists, skipping setup")
                return
            }
            
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            
            let predicate = HKQuery.predicateForSamples(
                withStart: startOfDay,
                end: nil,
                options: .strictStartDate
            )
            
            // Create an observer query that will notify us of changes
            let query = HKObserverQuery(sampleType: stepType, predicate: predicate) { [weak self] _, completionHandler, error in
                if error == nil {
                    DispatchQueue.main.async {
                        // Only use HealthKit updates if real-time isn't active
                        if !(self?.isRealtimeActive ?? false) {
                            self?.fetchTodaysSteps()
                        }
                    }
                }
                completionHandler()
            }
            
            healthStore.execute(query)
            stepQuery = query
            
            // Enable background delivery for step count updates
            healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
                if let error = error {
                    print("❌ Failed to enable background delivery: \(error.localizedDescription)")
                } else {
                    print("✅ Background delivery enabled")
                }
            }
        }
    
    // MARK: - Data Fetching Methods
    func fetchTodaysSteps() {
        guard authorizationStatus == "Authorized" else {
            print("❌ Can't fetch steps - not authorized: \(authorizationStatus)")
            return
        }
        
        // Don't fetch if real-time is active (to avoid conflicts)
        if isRealtimeActive {
            print("⚡ Skipping HealthKit fetch - real-time is active")
            return
        }
        
        print("📊 Fetching today's steps from HealthKit...")
        
        // Start loading timer (will show loading after 5 seconds if still fetching)
        startLoadingTimer()
        
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
        ) { [weak self] _, result, error in
            DispatchQueue.main.async {
                // Stop loading timer and hide loading indicator
                self?.stopLoadingTimer()
                
                if let error = error {
                    print("❌ Error fetching steps: \(error.localizedDescription)")
                    return
                }
                
                if let sum = result?.sumQuantity() {
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    let previousSteps = self?.stepCount ?? 0
                    
                    // Smooth update with animation
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self?.stepCount = steps
                    }
                    
                    print("✅ HealthKit update: \(previousSteps) → \(steps)")
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self?.stepCount = 0
                    }
                    print("✅ No step data found, set to 0")
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchWeeklySteps() {
        guard authorizationStatus == "Authorized" else { return }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let startDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: Date()))! // Last 30 days
        
        print("📊 Fetching 30-day history from \(startDate) to \(endDate)")
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        
        query.initialResultsHandler = { [weak self] _, results, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching step history: \(error.localizedDescription)")
                    return
                }
                
                guard let results = results else {
                    print("❌ No results from step history query")
                    return
                }
                
                var stepDataArray: [StepData] = []
                let today = calendar.startOfDay(for: Date())
                
                // Create entries for each day in the range (30 days)
                for dayOffset in 0..<30 {
                    guard let dayDate = calendar.date(byAdding: .day, value: -29 + dayOffset, to: today) else { continue }
                    
                    var daySteps = 0
                    results.enumerateStatistics(from: dayDate, to: calendar.date(byAdding: .day, value: 1, to: dayDate)!) { statistic, _ in
                        if calendar.isDate(statistic.startDate, inSameDayAs: dayDate) {
                            daySteps = Int(statistic.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
                        }
                    }
                    
                    // For today, use current step count if available
                    if calendar.isDate(dayDate, inSameDayAs: today), let currentSteps = self?.stepCount, currentSteps > daySteps {
                        daySteps = currentSteps
                    }
                    
                    let targetSteps = self?.targetManager.getTargetForDate(dayDate) ?? 10000
                    let notificationCount = self?.notificationManager?.getInactivityNotificationCount(for: dayDate) ?? 0
                    
                    var stepData = StepData(date: dayDate, steps: daySteps, targetSteps: targetSteps)
                    stepData.inactivityNotifications = notificationCount
                    stepDataArray.append(stepData)
                    
                    // Save to Core Data for persistence
                    self?.saveStepData(daySteps, for: dayDate, target: targetSteps)
                }
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    self?.weeklySteps = stepDataArray.sorted { $0.date < $1.date }
                }
                
                print("✅ 30-day step history updated: \(stepDataArray.count) days")
                self?.updateNotificationManager()
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchWeekdayAverage(for weekday: Int, completion: @escaping (Int) -> Void) {
        guard authorizationStatus == "Authorized" else {
            print("❌ Not authorized for HealthKit")
            completion(0)
            return
        }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let now = Date()
        
        // Get data from the last 12 weeks for better average calculation
        let startDate = calendar.date(byAdding: .weekOfYear, value: -12, to: now)!
        
        print("🔍 Fetching weekday average for weekday \(weekday) (\(weekdayName(for: weekday)))")
        print("📅 Date range: \(startDate) to \(now)")
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        
        query.initialResultsHandler = { [weak self] _, results, error in
            if let error = error {
                print("❌ Error fetching weekday average: \(error.localizedDescription)")
                completion(0)
                return
            }
            
            guard let results = results else {
                print("❌ No results for weekday average")
                completion(0)
                return
            }
            
            var weekdaySteps: [Int] = []
            var allDaysDebug: [(date: Date, weekday: Int, steps: Int)] = []
            
            results.enumerateStatistics(from: startDate, to: now) { statistic, _ in
                let statisticWeekday = calendar.component(.weekday, from: statistic.startDate)
                let steps = Int(statistic.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
                
                // Debug info for all days
                allDaysDebug.append((date: statistic.startDate, weekday: statisticWeekday, steps: steps))
                
                // Only include data for the specified weekday
                if statisticWeekday == weekday {
                    weekdaySteps.append(steps)
                    
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    print("✅ Found \(self?.weekdayName(for: weekday) ?? "Unknown") (\(weekday)): \(formatter.string(from: statistic.startDate)) - \(steps) steps")
                }
            }
            
            // Debug: Print sample of all days to verify weekday calculation
            let sampleDays = allDaysDebug.prefix(10)
            print("📊 Sample days (first 10):")
            for day in sampleDays {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d (E)"
                print("   \(formatter.string(from: day.date)): weekday=\(day.weekday), steps=\(day.steps)")
            }
            
            let average = weekdaySteps.isEmpty ? 0 : weekdaySteps.reduce(0, +) / weekdaySteps.count
            
            print("📊 \(self?.weekdayName(for: weekday) ?? "Unknown") (\(weekday)) average: \(average) steps (from \(weekdaySteps.count) days)")
            print("📈 Individual \(self?.weekdayName(for: weekday) ?? "Unknown") step counts: \(weekdaySteps)")
            
            completion(average)
        }
        
        healthStore.execute(query)
    }
    
    private func weekdayName(for weekday: Int) -> String {
        // Note: Calendar.component(.weekday, ...) returns:
        // 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday, 7 = Saturday
        let weekdays = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return weekdays[safe: weekday] ?? "Unknown"
    }
    
    // Test actual HealthKit access by attempting to read data
    private func testHealthKitAccess(completion: @escaping (Bool) -> Void) {
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
            DispatchQueue.main.async {
                if error != nil {
                    print("❌ HealthKit access test failed: \(error!.localizedDescription)")
                    completion(false)
                } else {
                    // If we get here without error, we have access
                    print("✅ HealthKit access test successful")
                    completion(true)
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Fetch Hourly Step Data for Activity Patterns
    func fetchHourlyStepData(for date: Date, completion: @escaping ([HourlyStepData]) -> Void) {
        guard authorizationStatus == "Authorized" else {
            print("❌ Not authorized for HealthKit - hourly data")
            completion([])
            return
        }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        
        // Get the full day from start to end
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        print("📊 Fetching hourly data for \(startOfDay)")
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        // Create hourly intervals
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startOfDay,
            intervalComponents: DateComponents(hour: 1)
        )
        
        query.initialResultsHandler = { [weak self] _, results, error in
            if let error = error {
                print("❌ Error fetching hourly data: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let results = results else {
                print("❌ No hourly results")
                completion([])
                return
            }
            
            var hourlyData: [HourlyStepData] = []
            
            // Create data for each hour (0-23)
            for hour in 0..<24 {
                let hourStart = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
                let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)!
                
                var hourSteps = 0
                
                // Get statistics for this specific hour
                results.enumerateStatistics(from: hourStart, to: hourEnd) { statistic, _ in
                    if let sum = statistic.sumQuantity() {
                        hourSteps = Int(sum.doubleValue(for: HKUnit.count()))
                    }
                }
                
                // Get notification count for this hour from NotificationManager
                let notifications = self?.getEnhancedHourlyNotificationCount(for: date, hour: hour) ?? 0
                
                hourlyData.append(HourlyStepData(
                    hour: hour,
                    steps: hourSteps,
                    notifications: notifications
                ))
            }
            
            print("✅ Fetched hourly data for \(calendar.dateComponents([.month, .day], from: date)): \(hourlyData.map(\.steps).reduce(0, +)) total steps")
            completion(hourlyData)
        }
        
        healthStore.execute(query)
    }
        
    func fetch30DayActivityData(completion: @escaping ([DayActivityData]) -> Void) {
            guard authorizationStatus == "Authorized" else {
                print("❌ Not authorized for HealthKit - returning empty activity data")
                completion([])
                return
            }
            
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let dispatchGroup = DispatchGroup()
            
            var activityDataArray: [DayActivityData] = []
            let queue = DispatchQueue(label: "enhanced-activity-data-fetch", qos: .userInitiated, attributes: .concurrent)
            
            print("🔍 Starting enhanced 30-day activity data fetch...")
            
            // Use concurrent queue for better performance
            for dayOffset in 0..<30 {
                guard let dayDate = calendar.date(byAdding: .day, value: -29 + dayOffset, to: today) else { continue }
                
                dispatchGroup.enter()
                
                queue.async { [weak self] in
                    self?.fetchEnhancedHourlyStepData(for: dayDate) { hourlyData in
                        let totalSteps = hourlyData.map(\.steps).reduce(0, +)
                        let totalNotifications = hourlyData.map(\.notifications).reduce(0, +)
                        let targetSteps = self?.targetManager.getTargetForDate(dayDate) ?? 10000
                        
                        let dayActivity = DayActivityData(
                            date: dayDate,
                            hourlyData: hourlyData,
                            totalSteps: totalSteps,
                            totalNotifications: totalNotifications,
                            targetSteps: targetSteps
                        )
                        
                        DispatchQueue.main.async {
                            activityDataArray.append(dayActivity)
                            dispatchGroup.leave()
                        }
                    }
                }
            }
            
            // Wait for all fetches to complete with timeout
            let timeoutResult = dispatchGroup.wait(timeout: .now() + 30) // 30 second timeout
            
            DispatchQueue.main.async {
                if timeoutResult == .timedOut {
                    print("⚠️ Activity data fetch timed out - returning partial results")
                }
                
                let sortedData = activityDataArray.sorted { $0.date > $1.date }
                print("✅ Enhanced activity data fetch complete: \(sortedData.count)/30 days")
                completion(sortedData)
            }
        }
        
        /// Enhanced hourly step data fetching with better notification integration
        private func fetchEnhancedHourlyStepData(for date: Date, completion: @escaping ([HourlyStepData]) -> Void) {
            guard authorizationStatus == "Authorized" else {
                completion([])
                return
            }
            
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let predicate = HKQuery.predicateForSamples(
                withStart: startOfDay,
                end: endOfDay,
                options: .strictStartDate
            )
            
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startOfDay,
                intervalComponents: DateComponents(hour: 1)
            )
            
            query.initialResultsHandler = { [weak self] _, results, error in
                if let error = error {
                    print("❌ Error fetching enhanced hourly data for \(date): \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let results = results else {
                    print("❌ No enhanced hourly results for \(date)")
                    completion([])
                    return
                }
                
                var hourlyData: [HourlyStepData] = []
                
                // Create comprehensive data for each hour
                for hour in 0..<24 {
                    let hourStart = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
                    let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)!
                    
                    var hourSteps = 0
                    
                    // Get step statistics for this hour
                    results.enumerateStatistics(from: hourStart, to: hourEnd) { statistic, _ in
                        if let sum = statistic.sumQuantity() {
                            hourSteps = Int(sum.doubleValue(for: HKUnit.count()))
                        }
                    }
                    
                    // Get notification count for this hour with enhanced accuracy
                    let notifications = self?.getEnhancedHourlyNotificationCount(for: date, hour: hour) ?? 0
                    
                    hourlyData.append(HourlyStepData(
                        hour: hour,
                        steps: hourSteps,
                        notifications: notifications
                    ))
                }
                
                let totalSteps = hourlyData.map(\.steps).reduce(0, +)
                print("✅ Enhanced hourly data for \(calendar.dateComponents([.month, .day], from: date)): \(totalSteps) total steps, \(hourlyData.map(\.notifications).reduce(0, +)) notifications")
                
                completion(hourlyData)
            }
            
            healthStore.execute(query)
        }
        
        /// Enhanced notification counting with better accuracy
        private func getEnhancedHourlyNotificationCount(for date: Date, hour: Int) -> Int {
            guard let notificationManager = notificationManager else { return 0 }
            
            // Use the enhanced notification manager method
            return notificationManager.getHourlyNotificationCount(for: date, hour: hour)
        }
        
        // MARK: - Activity Pattern Analysis Methods
        
        /// Calculate the most consistently active time period
        func getMostActiveTimePeriod(from activityData: [DayActivityData]) -> (startHour: Int, endHour: Int, averageSteps: Int)? {
            // Analyze 2-hour windows to find most consistently active period
            var windowAverages: [(startHour: Int, endHour: Int, averageSteps: Double)] = []
            
            // Check all possible 2-hour windows during waking hours (6 AM - 11 PM)
            for startHour in 6..<22 {
                let endHour = startHour + 1
                var totalSteps: Double = 0
                var validDays = 0
                
                for dayData in activityData {
                    let windowSteps = dayData.hourlyData
                        .filter { $0.hour >= startHour && $0.hour <= endHour }
                        .map(\.steps)
                        .reduce(0, +)
                    
                    if windowSteps > 0 { // Only count days with activity
                        totalSteps += Double(windowSteps)
                        validDays += 1
                    }
                }
                
                if validDays > 0 {
                    let average = totalSteps / Double(validDays)
                    windowAverages.append((startHour: startHour, endHour: endHour, averageSteps: average))
                }
            }
            
            // Find the window with highest average
            guard let bestWindow = windowAverages.max(by: { $0.averageSteps < $1.averageSteps }) else {
                return nil
            }
            
            return (startHour: bestWindow.startHour, endHour: bestWindow.endHour, averageSteps: Int(bestWindow.averageSteps))
        }
        
        /// Calculate the most problematic (inactive) time period
        func getMostInactiveTimePeriod(from activityData: [DayActivityData]) -> (startHour: Int, endHour: Int, averageNotifications: Double)? {
            // Analyze 2-hour windows for inactivity patterns
            var windowNotifications: [(startHour: Int, endHour: Int, averageNotifications: Double)] = []
            
            // Check waking hours only
            for startHour in 6..<22 {
                let endHour = startHour + 1
                var totalNotifications: Double = 0
                var validDays = 0
                
                for dayData in activityData {
                    let windowNotifications = dayData.hourlyData
                        .filter { $0.hour >= startHour && $0.hour <= endHour }
                        .map(\.notifications)
                        .reduce(0, +)
                    
                    totalNotifications += Double(windowNotifications)
                    validDays += 1
                }
                
                if validDays > 0 {
                    let average = totalNotifications / Double(validDays)
                    windowNotifications.append((startHour: startHour, endHour: endHour, averageNotifications: average))
                }
            }
            
            // Find the window with most notifications
            guard let worstWindow = windowNotifications.max(by: { $0.averageNotifications < $1.averageNotifications }),
                  worstWindow.averageNotifications > 0 else {
                return nil
            }
            
            return (startHour: worstWindow.startHour, endHour: worstWindow.endHour, averageNotifications: worstWindow.averageNotifications)
        }
        
        /// Get activity consistency score (0-100)
        func getActivityConsistencyScore(from activityData: [DayActivityData]) -> Int {
            guard !activityData.isEmpty else { return 0 }
            
            var consistentHours = 0
            let minimumStepsPerHour = 100 // Threshold for "active" hour
            let wakingHours = Array(6..<23) // 6 AM to 11 PM
            
            for hour in wakingHours {
                var activeDays = 0
                
                for dayData in activityData {
                    if let hourData = dayData.hourlyData.first(where: { $0.hour == hour }),
                       hourData.steps >= minimumStepsPerHour {
                        activeDays += 1
                    }
                }
                
                // Consider hour "consistent" if active in 70% of days
                let consistencyThreshold = Double(activityData.count) * 0.7
                if Double(activeDays) >= consistencyThreshold {
                    consistentHours += 1
                }
            }
            
            // Score based on how many waking hours are consistently active
            let maxPossibleHours = wakingHours.count
            return Int((Double(consistentHours) / Double(maxPossibleHours)) * 100)
        }
        
        /// Get detailed activity insights for UI display
        func getActivityInsights(from activityData: [DayActivityData]) -> ActivityInsights {
            let mostActiveWindow = getMostActiveTimePeriod(from: activityData)
            let mostInactiveWindow = getMostInactiveTimePeriod(from: activityData)
            let consistencyScore = getActivityConsistencyScore(from: activityData)
            
            // Calculate total statistics
            let totalSteps = activityData.map(\.totalSteps).reduce(0, +)
            let averageDailySteps = activityData.isEmpty ? 0 : totalSteps / activityData.count
            let totalNotifications = activityData.map(\.totalNotifications).reduce(0, +)
            let goalsAchieved = activityData.filter { $0.totalSteps >= $0.targetSteps }.count
            
            // Calculate peak activity hour across all days
            var hourlyTotals: [Int: Int] = [:]
            for dayData in activityData {
                for hourData in dayData.hourlyData {
                    if hourData.hour >= 6 && hourData.hour < 23 { // Waking hours only
                        hourlyTotals[hourData.hour, default: 0] += hourData.steps
                    }
                }
            }
            
            let peakActivityHour = hourlyTotals.max(by: { $0.value < $1.value })?.key ?? 12
            
            return ActivityInsights(
                mostActiveWindow: mostActiveWindow,
                mostInactiveWindow: mostInactiveWindow,
                consistencyScore: consistencyScore,
                averageDailySteps: averageDailySteps,
                totalNotifications: totalNotifications,
                goalsAchievedCount: goalsAchieved,
                peakActivityHour: peakActivityHour,
                dataRange: activityData.count
            )
        }
    }

    // MARK: - Activity Insights Data Model
    struct ActivityInsights {
        let mostActiveWindow: (startHour: Int, endHour: Int, averageSteps: Int)?
        let mostInactiveWindow: (startHour: Int, endHour: Int, averageNotifications: Double)?
        let consistencyScore: Int // 0-100
        let averageDailySteps: Int
        let totalNotifications: Int
        let goalsAchievedCount: Int
        let peakActivityHour: Int
        let dataRange: Int // Number of days analyzed
        
        var peakActivityTime: String {
            formatHour(peakActivityHour)
        }
        
        var mostActiveTimeRange: String? {
            guard let window = mostActiveWindow else { return nil }
            return "\(formatHour(window.startHour)) - \(formatHour(window.endHour + 1))"
        }
        
        var mostInactiveTimeRange: String? {
            guard let window = mostInactiveWindow else { return nil }
            return "\(formatHour(window.startHour)) - \(formatHour(window.endHour + 1))"
        }
        
        var consistencyLevel: String {
            switch consistencyScore {
            case 80...100: return "Excellent"
            case 60...79: return "Good"
            case 40...59: return "Fair"
            case 20...39: return "Needs Work"
            default: return "Poor"
            }
        }
        
        var goalSuccessRate: Int {
            guard dataRange > 0 else { return 0 }
            return Int((Double(goalsAchievedCount) / Double(dataRange)) * 100)
        }
        
        private func formatHour(_ hour: Int) -> String {
            if hour == 0 { return "12 AM" }
            if hour < 12 { return "\(hour) AM" }
            if hour == 12 { return "12 PM" }
            return "\(hour - 12) PM"
        }
    }


//    /// Get more accurate hourly notification count with caching
//    func getHourlyNotificationCount(for date: Date, hour: Int) -> Int {
//        let calendar = Calendar.current
//        let dateKey = dateToString(calendar.startOfDay(for: date))
//        
//        // Use cached data for better performance
//        return hourlyCountsCache[dateKey]?[hour] ?? 0
//    }
    
//    /// Get notification distribution pattern for insights
//    func getNotificationDistributionPattern() -> [Int: Double] {
//        var hourlyTotals: [Int: Int] = [:]
//        var totalDays = Set<String>()
//        
//        for timestamp in notificationTimestamps {
//            let hour = timestamp.hour
//            let dayKey = timestamp.dayKey
//            
//            hourlyTotals[hour, default: 0] += 1
//            totalDays.insert(dayKey)
//        }
//        
//        // Calculate average per day for each hour
//        let dayCount = max(totalDays.count, 1)
//        var averages: [Int: Double] = [:]
//        
//        for hour in 0..<24 {
//            let total = hourlyTotals[hour] ?? 0
//            averages[hour] = Double(total) / Double(dayCount)
//        }
//        
//        return averages
//    }
    
    /// Get activity correlation with notifications
    func getActivityNotificationCorrelation(from activityData: [DayActivityData]) -> Double {
        guard !activityData.isEmpty else { return 0 }
        
        var correlationSum: Double = 0
        var validHours = 0
        
        for dayData in activityData {
            for hourData in dayData.hourlyData {
                // Skip sleep hours for more accurate correlation
                if hourData.hour >= 6 && hourData.hour < 23 {
                    // Simple inverse correlation: more steps = fewer notifications expected
                    let expectedNotifications = hourData.steps < 100 ? 1.0 : 0.0
                    let actualNotifications = Double(hourData.notifications)
                    
                    // Calculate how well expectations match reality
                    let diff = abs(expectedNotifications - actualNotifications)
                    correlationSum += (1.0 - min(diff, 1.0)) // Inverse difference for correlation
                    validHours += 1
                }
            }
        }
        
        return validHours > 0 ? correlationSum / Double(validHours) : 0
    }
    
    private func dateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    
    



extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
