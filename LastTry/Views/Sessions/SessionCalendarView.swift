import SwiftUI

struct SessionCalendarErrorWrapper<Content: View>: View {
    let content: Content
    let message: String
    @Binding var isPresented: Bool
    
    init(message: String, isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.message = message
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        content
            .withErrorDisplay(
                message: message,
                severity: DisplayErrorSeverity.errorSeverity,
                isPresented: $isPresented
            )
    }
}

struct SessionCalendarView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var selectedDate = Date()
    @State private var currentMonth: Date = Date()
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    private let calendar = Calendar.current
    private let daySymbols = Calendar.current.veryShortWeekdaySymbols
    private let months = Calendar.current.monthSymbols
    
    var body: some View {
        SessionCalendarErrorWrapper(message: errorMessage, isPresented: $showError) {
            ScrollView {
                VStack(spacing: 20) {
                    // Month navigation
                    HStack {
                        Button(action: previousMonth) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20))
                                .foregroundColor(.appPrimary)
                        }
                        .frame(width: 44, height: 44)
                        .background(Color.appElevatedBackground)
                        .cornerRadius(22)
                        
                        Spacer()
                        
                        Text(monthYearString(from: currentMonth))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.appTextPrimary)
                        
                        Spacer()
                        
                        Button(action: nextMonth) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 20))
                                .foregroundColor(.appPrimary)
                        }
                        .frame(width: 44, height: 44)
                        .background(Color.appElevatedBackground)
                        .cornerRadius(22)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // Day headers
                    HStack(spacing: 0) {
                        ForEach(daySymbols, id: \.self) { day in
                            Text(day)
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.appTextSecondary)
                                .padding(.bottom, 8)
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.top, 40)
                    } else {
                        // Calendar grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                            ForEach(days) { day in
                                if day.date != nil {
                                    CalendarDayView(day: day, isSelected: calendar.isDate(day.date!, inSameDayAs: selectedDate))
                                        .onTapGesture {
                                            if let date = day.date {
                                                selectedDate = date
                                            }
                                        }
                                } else {
                                    Rectangle()
                                        .foregroundColor(.clear)
                                        .frame(height: 40)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 10)
                        
                        Divider()
                            .padding(.vertical, 16)
                        
                        // List of sessions for the selected date
                        VStack(alignment: .leading, spacing: 16) {
                            // Sessions on date header
                            HStack {
                                Image(systemName: "calendar.day.timeline.left")
                                    .font(.system(size: 20))
                                    .foregroundColor(.appPrimary)
                                
                                Text("Sessions on \(formatSelectedDate(selectedDate))")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.appTextPrimary)
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                            
                            let sessionsOnDate = appState.sessionManager.sessions.filter { 
                                calendar.isDate($0.date, inSameDayAs: selectedDate)
                            }
                            
                            if sessionsOnDate.isEmpty {
                                EmptyStateView(
                                    icon: "calendar.badge.exclamationmark",
                                    title: "No Sessions",
                                    message: "There are no sessions scheduled for this date"
                                )
                                .frame(height: 150)
                                .padding(.top, 10)
                            } else {
                                ForEach(sessionsOnDate) { session in
                                    SessionRowView(session: session)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color.appBackground)
            .withLoading(isLoading: isLoading, message: "Loading calendar...")
            .onAppear {
                loadCalendarData()
            }
            .onChange(of: appState.sessionManager.sessionError) { _, newError in
                if let sessionError = newError as? SessionError, let processedError = DetailedErrorProcessor.convertSessionError(sessionError) {
                    errorMessage = processedError.message
                    showError = true
                    isLoading = false
                    
                    // Clear error after user has seen it
                    appState.sessionManager.sessionError = nil
                }
            }
            .onDisappear {
                // Clear any errors when leaving the view
                appState.sessionManager.sessionError = nil
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadCalendarData() {
        isLoading = true
        
        // Using a slight delay to simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            resetCurrentMonth()
            appState.sessionManager.loadSessions()
            isLoading = false
        }
    }
    
    // Format the selected date in a more readable format
    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
    
    // MARK: - Calendar Helper Methods
    
    private func resetCurrentMonth() {
        let components = calendar.dateComponents([.year, .month], from: Date())
        currentMonth = calendar.date(from: components) ?? Date()
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private var days: [CalendarDay] {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        let firstDayOfMonth = calendar.date(from: components)!
        
        // Get the first day of the month's weekday (0 = Sunday, 1 = Monday, etc.)
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        // Calculate offset (if first day is Wednesday, offset is 3, etc.)
        let offset = firstWeekday - 1
        
        // Find the first date to display (may be from the previous month)
        let firstDate = calendar.date(byAdding: .day, value: -offset, to: firstDayOfMonth)!
        
        // Get the number of days in the month (not used directly)
        _ = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 30
        
        // Calculate total days needed for the grid (max 6 rows of 7 days)
        let totalDays = 42
        
        var calendarDays: [CalendarDay] = []
        
        for day in 0..<totalDays {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDate) {
                let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                
                let sessions = appState.sessionManager.sessions.filter {
                    calendar.isDate($0.date, inSameDayAs: date)
                }
                
                calendarDays.append(CalendarDay(
                    id: day,
                    date: date,
                    dayNumber: calendar.component(.day, from: date),
                    isCurrentMonth: isCurrentMonth,
                    hasSessions: !sessions.isEmpty
                ))
            }
        }
        
        return calendarDays
    }
}

// MARK: - Calendar Day Model and View

struct CalendarDay: Identifiable {
    let id: Int
    let date: Date?
    let dayNumber: Int
    let isCurrentMonth: Bool
    let hasSessions: Bool
}

struct CalendarDayView: View {
    let day: CalendarDay
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Background circle
            if isSelected {
                Circle()
                    .fill(Color.appPrimary)
                    .frame(width: 40, height: 40)
            } else if day.hasSessions {
                Circle()
                    .fill(Color.appElevatedBackground)
                    .frame(width: 40, height: 40)
            }
            
            // Day number
            Text("\(day.dayNumber)")
                .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                .foregroundColor(textColor)
        }
        .frame(height: 40)
    }
    
    private var textColor: Color {
        if isSelected {
            return Color.white
        } else if !day.isCurrentMonth {
            return Color.gray.opacity(0.5)
        } else if day.hasSessions {
            return Color.appPrimary
        } else {
            return Color.appTextPrimary
        }
    }
}

#Preview {
    SessionCalendarView()
        .environmentObject({
            let state = AppState()
            state.loadDemoData()
            return state
        }())
        .preferredColorScheme(.dark)
} 