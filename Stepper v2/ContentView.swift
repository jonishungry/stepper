//
//  ContentView.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//
import SwiftUI
import HealthKit

class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var stepCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var authorizationStatus: String = "Not Determined"
    
    init() {
        checkAuthorizationStatus()
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
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var healthManager = HealthManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Step Counter")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Step Count Display
                VStack(spacing: 20) {
                    if healthManager.authorizationStatus == "Authorized" {
                        if healthManager.isLoading {
                            ProgressView("Loading steps...")
                                .scaleEffect(1.2)
                        } else {
                            VStack(spacing: 10) {
                                Text("Today's Steps")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("\(healthManager.stepCount)")
                                    .font(.system(size: 72, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .animation(.easeInOut, value: healthManager.stepCount)
                                
                                Text("steps")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        }
                    } else if healthManager.authorizationStatus == "Not Determined" {
                        VStack(spacing: 15) {
                            Text("Health Access Required")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("This app needs access to your Health data to show your step count.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                healthManager.requestHealthKitPermission()
                            }) {
                                Text("Enable Health Access")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                        }
                        .padding()
                    } else if healthManager.authorizationStatus == "Denied" {
                        VStack(spacing: 15) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            
                            Text("Health Access Denied")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Please enable Health access in Settings to view your steps.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            }) {
                                Text("Open Settings")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .cornerRadius(12)
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
                
                // Refresh Button
                if healthManager.authorizationStatus == "Authorized" {
                    Button(action: {
                        healthManager.fetchTodaysSteps()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Steps")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    }
                    .disabled(healthManager.isLoading)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
        .onAppear {
            // Refresh steps when app appears
            if healthManager.authorizationStatus == "Authorized" {
                healthManager.fetchTodaysSteps()
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
