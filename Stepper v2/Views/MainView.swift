//
//  MainView.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//

import SwiftUI

// MARK: - Main View with Sidebar
struct MainView: View {
    @StateObject private var healthManager = HealthManager()
    @State private var showingSidebar = false
    @State private var selectedMenuItem: MenuItem = .today
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                Group {
                    switch selectedMenuItem {
                    case .today:
                        TodayStepsView(healthManager: healthManager)
                    case .history:
                        StepHistoryView(healthManager: healthManager)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSidebar.toggle()
                            }
                        }) {
                            Image(systemName: "line.horizontal.3")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Sidebar overlay
                if showingSidebar {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSidebar = false
                            }
                        }
                    
                    HStack {
                        SidebarView(
                            selectedMenuItem: $selectedMenuItem,
                            showingSidebar: $showingSidebar
                        )
                        .frame(width: 280)
                        
                        Spacer()
                    }
                    .transition(.move(edge: .leading))
                }
            }
        }
        .onAppear {
            if healthManager.authorizationStatus == "Authorized" {
                healthManager.fetchTodaysSteps()
                healthManager.fetchWeeklySteps()
            }
        }
    }
}
