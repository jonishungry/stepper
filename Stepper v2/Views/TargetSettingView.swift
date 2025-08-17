//
//  TargetSettingView.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//

import SwiftUI

// MARK: - Target Setting View
struct TargetSettingView: View {
    @ObservedObject var targetManager: TargetManager
    @Binding var isPresented: Bool
    @State private var targetText: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.stepperDarkBlue, Color.stepperTeal]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    VStack(spacing: 15) {
                        Text("Set Your Daily Goal! 🎯")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.stepperCream)
                        
                        Text("How many steps will you take today?")
                            .font(.body)
                            .foregroundColor(.stepperCream)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Current Goal")
                                .font(.headline)
                                .foregroundColor(.stepperCream.opacity(0.7))
                            
                            Text("\(targetManager.currentTarget) steps")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.stepperYellow)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.stepperCream.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.stepperYellow.opacity(0.3), lineWidth: 2)
                                )
                        )
                        
                        VStack(spacing: 15) {
                            Text("New Goal")
                                .font(.headline)
                                .foregroundColor(.stepperCream)
                            
                            TextField("Enter steps", text: $targetText)
                                .keyboardType(.numberPad)
                                .background(Color.stepperCream.opacity(0.2))
                                .font(.title2)
                                .foregroundColor(.stepperCream)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 15) {
                                ForEach([5000, 8000, 10000, 12000], id: \.self) { preset in
                                    Button(action: {
                                        targetText = "\(preset)"
                                    }) {
                                        Text("\(preset)")
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.stepperCream.opacity(0.2))
                                            .foregroundColor(.stepperCream)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Step Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.stepperCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let target = Int(targetText), target > 0 {
                            targetManager.saveTarget(target)
                            isPresented = false
                        }
                    }
                    .disabled(Int(targetText) == nil || Int(targetText) ?? 0 <= 0)
                    .foregroundColor(.stepperYellow)
                }
            }
        }
//        .onAppear {
//            targetText = "\(targetManager.currentTarget)"
//        }
        .onAppear {
            // Configure navigation bar appearance for this view
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.titleTextAttributes = [.foregroundColor: UIColor(Color.stepperCream)]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.stepperCream)]
            targetText = "\(targetManager.currentTarget)"
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}


