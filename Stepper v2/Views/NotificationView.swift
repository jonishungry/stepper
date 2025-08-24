import SwiftUI

// MARK: - Notification Settings View - Single Scrollable View
struct NotificationSettingsView: View {
    @ObservedObject var notificationManager: NotificationManager
    @State private var showingTimeIntervalEditor = false
    @State private var editingIntervalIndex: Int?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                NotificationHeaderView()
                
                if notificationManager.notificationPermissionStatus == .authorized {
                    // Bedtime Notification Section
                    BedtimeNotificationSection(notificationManager: notificationManager)
                    
                    // Inactivity Notification Section
                    InactivityNotificationSection(
                        notificationManager: notificationManager,
                        showingTimeIntervalEditor: $showingTimeIntervalEditor,
                        editingIntervalIndex: $editingIntervalIndex
                    )
                } else {
                    // Permission Request Section
                    NotificationPermissionView(notificationManager: notificationManager)
                }
                
                // Add some bottom padding
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 50)
            }
            .padding()
        }
        .sheet(isPresented: $showingTimeIntervalEditor) {
            TimeIntervalEditorView(
                notificationManager: notificationManager,
                editingIndex: editingIntervalIndex,
                isPresented: $showingTimeIntervalEditor
            )
        }
    }
}

// MARK: - Header View
struct NotificationHeaderView: View {
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 25))
                    .foregroundColor(.stepperYellow)
                
                Text("Notifications")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.stepperCream)
                
                Image(systemName: "bell.fill")
                    .font(.system(size: 25))
                    .foregroundColor(.stepperYellow)
            }
            
            Text("Stay motivated with smart reminders! 🔔")
                .font(.subheadline)
                .foregroundColor(.stepperCream.opacity(0.8))
        }
    }
}

// MARK: - Permission View
struct NotificationPermissionView: View {
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.stepperYellow)
            
            Text("Notification Permission Needed")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.stepperCream)
            
            Text("Enable notifications to receive helpful reminders about your step goals!")
                .multilineTextAlignment(.center)
                .foregroundColor(.stepperCream.opacity(0.8))
            
            Button(action: {
                notificationManager.requestNotificationPermission()
            }) {
                Text("Enable Notifications 🔔")
                    .font(.headline)
                    .foregroundColor(.stepperDarkBlue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.stepperYellow)
                    .cornerRadius(16)
            }
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
    }
}

// MARK: - Enhanced Bedtime Notification Section
struct BedtimeNotificationSection: View {
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(.stepperYellow)
                Text("Bedtime Reminder")
                    .font(.headline)
                    .foregroundColor(.stepperCream)
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { notificationManager.settings.bedtimeNotificationEnabled },
                    set: { value in
                        notificationManager.settings.bedtimeNotificationEnabled = value
                        notificationManager.saveSettings()
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .stepperYellow))
            }
            
            Text("Get reminded when you have limited time left to reach your goal before bedtime")
                .font(.caption)
                .foregroundColor(.stepperCream.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if notificationManager.settings.bedtimeNotificationEnabled {
                VStack(spacing: 20) {
                    // Bedtime Setting
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "bed.double.fill")
                                .foregroundColor(.stepperLightTeal)
                            Text("Your Bedtime")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.stepperCream)
                            Spacer()
                        }
                        
                        DatePicker("Bedtime",
                                 selection: Binding(
                                    get: { notificationManager.settings.customBedtime },
                                    set: { value in
                                        notificationManager.settings.customBedtime = value
                                        notificationManager.saveSettings()
                                    }
                                 ),
                                 displayedComponents: .hourAndMinute)
                            .datePickerStyle(CompactDatePickerStyle())
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.stepperTeal.opacity(0.2))
                    )
                    
                    // Reminder Timing
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundColor(.stepperLightTeal)
                            Text("Remind me before bedtime:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.stepperCream)
                            Spacer()
                        }
                        
                        HStack(spacing: 15) {
                            // Hours Picker
                            VStack(spacing: 8) {
                                Text("Hours")
                                    .font(.caption)
                                    .foregroundColor(.stepperCream.opacity(0.7))
                                
                                Picker("Hours", selection: Binding(
                                    get: { notificationManager.settings.bedtimeHours },
                                    set: { value in
                                        notificationManager.settings.bedtimeHours = value
                                        notificationManager.saveSettings()
                                    }
                                )) {
                                    ForEach(0...12, id: \.self) { hour in
                                        Text("\(hour)").tag(hour)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: 80, height: 100)
                            }
                            
                            // Minutes Picker
                            VStack(spacing: 8) {
                                Text("Minutes")
                                    .font(.caption)
                                    .foregroundColor(.stepperCream.opacity(0.7))
                                
                                Picker("Minutes", selection: Binding(
                                    get: { notificationManager.settings.bedtimeMinutes },
                                    set: { value in
                                        notificationManager.settings.bedtimeMinutes = value
                                        notificationManager.saveSettings()
                                    }
                                )) {
                                    ForEach(0...59, id: \.self) { minute in
                                        Text("\(minute)").tag(minute)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: 80, height: 100)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.stepperTeal.opacity(0.2))
                    )
                    
                    // Example Text
                    VStack(spacing: 5) {
                        Text("Example:")
                            .font(.caption)
                            .foregroundColor(.stepperLightTeal)
                            .fontWeight(.medium)
                        
                        Text("Reminder at \(getExampleReminderTime()) for \(getBedtimeString()) bedtime")
                            .font(.caption)
                            .foregroundColor(.stepperLightTeal)
                            .italic()
                    }
                }
            }
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
    }
    
    private func getExampleReminderTime() -> String {
        let calendar = Calendar.current
        let bedtime = notificationManager.settings.customBedtime
        let offsetMinutes = notificationManager.settings.bedtimeOffsetMinutes
        
        if let reminderTime = calendar.date(byAdding: .minute, value: -offsetMinutes, to: bedtime) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: reminderTime)
        }
        
        return "N/A"
    }
    
    private func getBedtimeString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: notificationManager.settings.customBedtime)
    }
}

// MARK: - Enhanced Inactivity Notification Section
struct InactivityNotificationSection: View {
    @ObservedObject var notificationManager: NotificationManager
    @Binding var showingTimeIntervalEditor: Bool
    @Binding var editingIntervalIndex: Int?
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundColor(.stepperYellow)
                Text("Inactivity Reminder")
                    .font(.headline)
                    .foregroundColor(.stepperCream)
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { notificationManager.settings.inactivityNotificationEnabled },
                    set: { value in
                        notificationManager.settings.inactivityNotificationEnabled = value
                        notificationManager.saveSettings()
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .stepperYellow))
            }
            
            Text("Get reminded when you haven't moved for a set amount of time during your active hours")
                .font(.caption)
                .foregroundColor(.stepperCream.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if notificationManager.settings.inactivityNotificationEnabled {
                VStack(spacing: 20) {
                    // Inactivity Duration Setting
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.stepperLightTeal)
                            Text("Remind me after")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.stepperCream)
                            Spacer()
                        }
                        
                        HStack(spacing: 10) {
                            Picker("Minutes", selection: Binding(
                                get: { notificationManager.settings.inactivityMinutes },
                                set: { value in
                                    notificationManager.settings.inactivityMinutes = value
                                    notificationManager.saveSettings()
                                }
                            )) {
                                ForEach([15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 90, 120], id: \.self) { minutes in
                                    Text("\(minutes) min").tag(minutes)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 100)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("of inactivity")
                                    .font(.subheadline)
                                    .foregroundColor(.stepperCream)
                                
                                Text("during active hours")
                                    .font(.caption)
                                    .foregroundColor(.stepperCream.opacity(0.7))
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.stepperTeal.opacity(0.2))
                    )
                    
                    // Active Hours Section
                    VStack(spacing: 15) {
                        HStack {
                            Image(systemName: "clock.circle")
                                .foregroundColor(.stepperLightTeal)
                            Text("Active Hours")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.stepperCream)
                            
                            Spacer()
                            
                            Button("Add Time Range") {
                                editingIntervalIndex = nil
                                showingTimeIntervalEditor = true
                            }
                            .font(.caption)
                            .foregroundColor(.stepperYellow)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.stepperYellow, lineWidth: 1)
                            )
                        }
                        
                        if notificationManager.settings.whitelistTimeIntervals.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "clock.badge.questionmark")
                                    .font(.title2)
                                    .foregroundColor(.stepperCream.opacity(0.5))
                                
                                Text("No active hours set")
                                    .font(.subheadline)
                                    .foregroundColor(.stepperCream.opacity(0.7))
                                    .fontWeight(.medium)
                                
                                Text("Add time ranges to receive inactivity reminders during those hours")
                                    .font(.caption)
                                    .foregroundColor(.stepperCream.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.stepperTeal.opacity(0.1))
                            )
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(notificationManager.settings.whitelistTimeIntervals.enumerated()), id: \.element.id) { index, interval in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Image(systemName: "clock.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.stepperYellow)
                                                
                                                Text(interval.formattedRange)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.stepperCream)
                                            }
                                            
                                            Text("Reminders active during this time")
                                                .font(.caption)
                                                .foregroundColor(.stepperCream.opacity(0.6))
                                        }
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 10) {
                                            Button(action: {
                                                editingIntervalIndex = index
                                                showingTimeIntervalEditor = true
                                            }) {
                                                Image(systemName: "pencil.circle.fill")
                                                    .font(.title3)
                                                    .foregroundColor(.stepperYellow)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
                                            Button(action: {
                                                notificationManager.removeTimeInterval(at: index)
                                            }) {
                                                Image(systemName: "trash.circle.fill")
                                                    .font(.title3)
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.stepperTeal.opacity(0.2))
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.stepperTeal.opacity(0.2))
                    )
                }
            }
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
    }
}

// MARK: - Time Interval Editor View
struct TimeIntervalEditorView: View {
    @ObservedObject var notificationManager: NotificationManager
    let editingIndex: Int?
    @Binding var isPresented: Bool
    
    @State private var startTime = Date()
    @State private var endTime = Date()
    
    private var isEditing: Bool {
        editingIndex != nil
    }
    
    private func getTimeRangePreview() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.stepperDarkBlue, Color.stepperTeal]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    HStack {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .foregroundColor(.stepperCream)
                        .font(.body)
                        
                        Spacer()
                        
                        Text(isEditing ? "Edit Range" : "Add Range")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.stepperCream)
                        
                        Spacer()
                        
                        Button("Save") {
                            if let index = editingIndex {
                                notificationManager.updateTimeInterval(at: index, startTime: startTime, endTime: endTime)
                            } else {
                                let newInterval = ActiveTimeRange(startTime: startTime, endTime: endTime)
                                notificationManager.settings.whitelistTimeIntervals.append(newInterval)
                                notificationManager.saveSettings()
                            }
                            isPresented = false
                        }
                        .foregroundColor(.stepperYellow)
                        .font(.body)
                        .fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color.stepperDarkBlue.opacity(0.8))
                    
                    // Scrollable Content
                    ScrollView {
                        VStack(spacing: 30) {
                            VStack(spacing: 15) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.stepperYellow)
                                
                                Text("Set your active hours for inactivity reminders")
                                    .font(.body)
                                    .foregroundColor(.stepperCream.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 20)
                            
                            VStack(spacing: 25) {
                                VStack(spacing: 15) {
                                    HStack {
                                        Image(systemName: "sunrise.fill")
                                            .foregroundColor(.stepperYellow)
                                        Text("Start Time")
                                            .font(.headline)
                                            .foregroundColor(.stepperCream)
                                        Spacer()
                                    }
                                    
                                    DatePicker("Start Time",
                                             selection: $startTime,
                                             displayedComponents: .hourAndMinute)
                                        .datePickerStyle(WheelDatePickerStyle())
                                        .labelsHidden()
                                        .frame(height: 120)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.stepperCream.opacity(0.1))
                                )
                                
                                VStack(spacing: 15) {
                                    HStack {
                                        Image(systemName: "sunset.fill")
                                            .foregroundColor(.stepperYellow)
                                        Text("End Time")
                                            .font(.headline)
                                            .foregroundColor(.stepperCream)
                                        Spacer()
                                    }
                                    
                                    DatePicker("End Time",
                                             selection: $endTime,
                                             displayedComponents: .hourAndMinute)
                                        .datePickerStyle(WheelDatePickerStyle())
                                        .labelsHidden()
                                        .frame(height: 120)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.stepperCream.opacity(0.1))
                                )
                            }
                            
                            // Preview
                            VStack(spacing: 5) {
                                Text("Preview:")
                                    .font(.caption)
                                    .foregroundColor(.stepperLightTeal)
                                    .fontWeight(.medium)
                                
                                Text(getTimeRangePreview())
                                    .font(.subheadline)
                                    .foregroundColor(.stepperYellow)
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.stepperTeal.opacity(0.3))
                            )
                            
                            // Instructions
                            VStack(spacing: 10) {
                                Text("💡 Tips:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.stepperYellow)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("• You'll only get reminders during these hours")
                                    Text("• Set multiple ranges for different parts of your day")
                                    Text("• Times can span midnight (e.g., 11:00 PM - 2:00 AM)")
                                }
                                .font(.caption)
                                .foregroundColor(.stepperCream.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.stepperCream.opacity(0.05))
                            )
                            
                            // Bottom padding to ensure content is visible above keyboard
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 50)
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if let index = editingIndex,
               index < notificationManager.settings.whitelistTimeIntervals.count {
                let interval = notificationManager.settings.whitelistTimeIntervals[index]
                startTime = interval.startTime
                endTime = interval.endTime
            } else {
                // Set default times (9 AM - 5 PM)
                let calendar = Calendar.current
                let now = Date()
                
                var startComponents = calendar.dateComponents([.year, .month, .day], from: now)
                startComponents.hour = 9
                startComponents.minute = 0
                startTime = calendar.date(from: startComponents) ?? now
                
                var endComponents = calendar.dateComponents([.year, .month, .day], from: now)
                endComponents.hour = 17
                endComponents.minute = 0
                endTime = calendar.date(from: endComponents) ?? now
            }
        }
    }
}
