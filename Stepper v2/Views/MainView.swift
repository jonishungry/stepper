//
//  MainView.swift
//  Stepper v2
//
//  Created by Jonathan Chan on 6/19/25.
//

import SwiftUI

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

struct SidebarView: View {
    @Binding var selectedMenuItem: MenuItem
    @Binding var showingSidebar: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "figure.walk")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    Text("Step Counter")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                }
                
                Text("Track your daily activity")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
            
            // Menu Items
            VStack(spacing: 0) {
                ForEach(MenuItem.allCases, id: \.self) { item in
                    Button(action: {
                        selectedMenuItem = item
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSidebar = false
                        }
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: item.icon)
                                .font(.title3)
                                .foregroundColor(selectedMenuItem == item ? .white : .primary)
                                .frame(width: 24)
                            
                            Text(item.rawValue)
                                .font(.body)
                                .foregroundColor(selectedMenuItem == item ? .white : .primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            selectedMenuItem == item ?
                            Color.blue : Color.clear
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 5, y: 0)
    }
}
