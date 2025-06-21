//
//  HealthManager.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//

import SwiftUI
import HealthKit

// MARK: - Health Manager
class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var stepCount: Int = 0
    @Published var weeklySteps: [StepData] = []
    @Published var isLoading: Bool = false
    @Published var authorizationStatus: String = "Not Determined"
    
    private let targetManager = TargetManager()
    
    init() {
        checkAuthorizationStatus()
    }
    
    func getTargetManager() -> TargetManager {
        return targetManager
    }
    
    func requestHealthKitPermission() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = "Health data not available"
            return
        }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let typesToRead: Set<HKObjectType> = [stepType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.authorizationStatus = "Authorized"
                    self?.fetchTodaysSteps()
                    self?.fetchWeeklySteps()
                } else {
                    self?.authorizationStatus = "Denied"
                }
            }
        }
    }
    
    func checkAuthorizationStatus() {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let status = healthStore.authorizationStatus(for: stepType)
        
        switch status {
        case .notDetermined:
            authorizationStatus = "Not Determined"
        case .sharingDenied:
            authorizationStatus = "Denied"
        case .sharingAuthorized:
            authorizationStatus = "Authorized"
            fetchTodaysSteps()
            fetchWeeklySteps()
        @unknown default:
            authorizationStatus = "Unknown"
        }
    }
    
    func fetchTodaysSteps() {
        guard authorizationStatus == "Authorized" else { return }
        
        isLoading = true
        
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
                self?.isLoading = false
                
                if let error = error {
                    print("Error fetching steps: \(error.localizedDescription)")
                    return
                }
                
                if let sum = result?.sumQuantity() {
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    self?.stepCount = steps
                } else {
                    self?.stepCount = 0
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchWeeklySteps() {
        guard authorizationStatus == "Authorized" else { return }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -6, to: endDate)!
        
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
                    print("Error fetching weekly steps: \(error.localizedDescription)")
                    return
                }
                
                guard let results = results else { return }
                
                var stepDataArray: [StepData] = []
                
                results.enumerateStatistics(from: startDate, to: endDate) { statistic, _ in
                    let steps = statistic.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    let targetSteps = self?.targetManager.getTargetForDate(statistic.startDate) ?? 10000
                    let stepData = StepData(date: statistic.startDate, steps: Int(steps), targetSteps: targetSteps)
                    stepDataArray.append(stepData)
                }
                
                self?.weeklySteps = stepDataArray.sorted { $0.date < $1.date }
            }
        }
        
        healthStore.execute(query)
    }
}
