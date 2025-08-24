import SwiftUI

// MARK: - Main View with Sidebar and Notifications
struct MainView: View {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var notificationManager = NotificationManager()
    @State private var showingSidebar = false
    @State private var selectedMenuItem: MenuItem = .today
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                LinearGradient(
                    gradient: Gradient(colors: [Color.stepperDarkBlue, Color.stepperTeal]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                Group {
                    switch selectedMenuItem {
                    case .today:
                        TodayStepsView(healthManager: healthManager)
                    case .history:
                        StepHistoryView(healthManager: healthManager)
                    case .notifications:
                        NotificationSettingsView(notificationManager: notificationManager)
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
            // Set up Core Data context
            healthManager.setContext(PersistenceController.shared.container.viewContext)
            
            // Connect health manager to notification manager
            healthManager.setNotificationManager(notificationManager)
            
            // Only fetch data if authorized - don't auto-request permission
            if healthManager.authorizationStatus == "Authorized" {
                healthManager.fetchTodaysSteps()
                healthManager.fetchWeeklySteps()
            }
        }
    }
}
