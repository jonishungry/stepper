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
        
        let currentTarget = targetManager.currentTarget
        notificationManager.updateStepCount(stepCount, targetSteps: currentTarget)
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
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let typesToRead: Set<HKObjectType> = [stepType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    // Test if we can actually read data to confirm authorization
                    self?.testHealthKitAccess { hasAccess in
                        if hasAccess {
                            // Store authorization locally for persistence
                            UserDefaults.standard.set(true, forKey: self?.authorizationKey ?? "")
                            self?.authorizationStatus = "Authorized"
                            print("✅ HealthKit authorization confirmed and stored")
                            
                            // Start tracking
                            if !(self?.isRealtimeActive ?? false) {
                                self?.startHybridTracking()
                                self?.fetchWeeklySteps()
                                self?.setupLiveQuery()
                            }
                        } else {
                            self?.authorizationStatus = "Denied"
                            UserDefaults.standard.set(false, forKey: self?.authorizationKey ?? "")
                            print("❌ HealthKit authorization denied")
                        }
                    }
                } else {
                    self?.authorizationStatus = "Denied"
                    UserDefaults.standard.set(false, forKey: self?.authorizationKey ?? "")
                    print("❌ HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
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
        
        // First check if we have previously stored authorization
        let hasStoredAuth = UserDefaults.standard.bool(forKey: authorizationKey)
        
        if hasStoredAuth {
            print("✅ Found stored HealthKit authorization")
            
            // Test if we still have access (user might have revoked in Settings)
            testHealthKitAccess { [weak self] hasAccess in
                if hasAccess {
                    self?.authorizationStatus = "Authorized"
                    print("✅ HealthKit access confirmed - Starting tracking")
                    
                    // Only start tracking if we're not already tracking
                    if !(self?.isRealtimeActive ?? false) {
                        self?.startHybridTracking()
                        self?.fetchWeeklySteps()
                        self?.setupLiveQuery()
                    }
                } else {
                    // Access was revoked - clear stored preference
                    UserDefaults.standard.set(false, forKey: self?.authorizationKey ?? "")
                    self?.authorizationStatus = "Denied"
                    print("❌ HealthKit access revoked - cleared stored auth")
                }
            }
        } else {
            // No stored authorization - check system status
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let status = healthStore.authorizationStatus(for: stepType)
            
            DispatchQueue.main.async {
                switch status {
                case .notDetermined:
                    self.authorizationStatus = "Not Determined"
                    print("🔐 HealthKit status: Not Determined")
                    
                case .sharingDenied:
                    self.authorizationStatus = "Denied"
                    print("❌ HealthKit status: Denied")
                    
                case .sharingAuthorized:
                    // Even if system says authorized, test actual access
                    self.testHealthKitAccess { [weak self] hasAccess in
                        if hasAccess {
                            UserDefaults.standard.set(true, forKey: self?.authorizationKey ?? "")
                            self?.authorizationStatus = "Authorized"
                            print("✅ HealthKit system authorized and confirmed - Starting tracking")
                            
                            if !(self?.isRealtimeActive ?? false) {
                                self?.startHybridTracking()
                                self?.fetchWeeklySteps()
                                self?.setupLiveQuery()
                            }
                        } else {
                            self?.authorizationStatus = "Denied"
                            print("❌ HealthKit system authorized but access test failed")
                        }
                    }
                    
                @unknown default:
                    self.authorizationStatus = "Unknown"
                    print("⚠️ HealthKit status: Unknown")
                }
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
        let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))! // Include full today
        let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date()))! // Last 7 days including today
        
        print("📊 Fetching weekly steps from \(startDate) to \(endDate)")
        
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
                    print("❌ Error fetching weekly steps: \(error.localizedDescription)")
                    return
                }
                
                guard let results = results else {
                    print("❌ No results from weekly steps query")
                    return
                }
                
                var stepDataArray: [StepData] = []
                let today = calendar.startOfDay(for: Date())
                
                // Create entries for each day in the range
                for dayOffset in 0..<7 {
                    guard let dayDate = calendar.date(byAdding: .day, value: -6 + dayOffset, to: today) else { continue }
                    
                    // Find statistics for this specific day
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
                    let stepData = StepData(date: dayDate, steps: daySteps, targetSteps: targetSteps)
                    stepDataArray.append(stepData)
                    
                    // Save to Core Data for persistence
                    self?.saveStepData(daySteps, for: dayDate, target: targetSteps)
                    
                    print("📅 \(dayDate): \(daySteps) steps (target: \(targetSteps))")
                }
                
                // Smooth update for weekly steps
                withAnimation(.easeInOut(duration: 0.5)) {
                    self?.weeklySteps = stepDataArray.sorted { $0.date < $1.date }
                }
                
                print("✅ Weekly steps updated: \(stepDataArray.count) days")
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
}


extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
