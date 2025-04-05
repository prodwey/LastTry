import SwiftUI

enum SessionTab: String, CaseIterable, Identifiable {
    case book = "Book"
    case past = "Past"
    case calendar = "Calendar"
    
    var id: String { self.rawValue }
}

struct SessionsContainerView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SessionTab = .book
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                    
                VStack(spacing: 0) {
                    // Custom tab picker
                    HStack(spacing: 0) {
                        ForEach(SessionTab.allCases) { tab in
                            Button(action: {
                                selectedTab = tab
                            }) {
                                VStack(spacing: 8) {
                                    Text(tab.rawValue)
                                        .font(.headline)
                                        .foregroundColor(selectedTab == tab ? .appPrimary : .appTextSecondary)
                                    
                                    Rectangle()
                                        .fill(selectedTab == tab ? Color.appPrimary : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    .background(Color.appBackground)
                    
                    // Tab content
                    TabView(selection: $selectedTab) {
                        BookSessionView()
                            .tag(SessionTab.book)
                        
                        PastSessionsView()
                            .tag(SessionTab.past)
                        
                        SessionCalendarView()
                            .tag(SessionTab.calendar)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: selectedTab)
                }
            }
            .navigationTitle("Sessions")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    SessionsContainerView()
        .environmentObject(AppState())
} 