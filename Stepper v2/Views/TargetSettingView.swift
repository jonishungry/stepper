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
            VStack(spacing: 30) {
                VStack(spacing: 15) {
                    Image(systemName: "target")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Set Daily Step Target")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("This target will be used for today and all future days until changed.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Current Target")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("\(targetManager.currentTarget) steps")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                    )
                    
                    VStack(spacing: 15) {
                        Text("New Target")
                            .font(.headline)
                        
                        TextField("Enter steps", text: $targetText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.title2)
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
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Step Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let target = Int(targetText), target > 0 {
                            targetManager.saveTarget(target)
                            isPresented = false
                        }
                    }
                    .disabled(Int(targetText) == nil || Int(targetText) ?? 0 <= 0)
                }
            }
        }
        .onAppear {
            targetText = "\(targetManager.currentTarget)"
        }
    }
}
