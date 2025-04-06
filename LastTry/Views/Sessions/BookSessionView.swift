import SwiftUI
import Foundation

// Helper wrapper to avoid "error" naming conflict
struct SessionErrorDisplayWrapper<Content: View>: View {
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

struct BookSessionView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var selectedStudio: Studio = .studioA
    @State private var mainProducer = ""
    @State private var additionalProducers = ""
    @State private var singers = ""
    @State private var selectedDate = Date()
    @State private var duration: Double = 180 // Default to 3 hours
    
    @State private var showBookingSuccessAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    // Explicit initializer to avoid ambiguity
    init() {
        // No custom initialization needed
    }
    
    var body: some View {
        SessionErrorDisplayWrapper(message: errorMessage, isPresented: $showError) {
            ScrollView {
                VStack(spacing: 20) {
                    // Studio selection with images
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Studio")
                            .font(.headline)
                            .foregroundColor(.appTextPrimary)
                        
                        studioSelection
                    }
                    .padding(.top, 20)
                    
                    // Form fields
                    VStack(spacing: 16) {
                        // Main producer
                        AppFormField(
                            title: "Main Producer",
                            placeholder: "Producer Name",
                            text: $mainProducer,
                            errorMessage: mainProducer.isEmpty ? "Producer name is required" : nil
                        )
                        
                        // Additional producers
                        AppFormField(
                            title: "Additional Producers (comma separated)",
                            placeholder: "Additional Producers",
                            text: $additionalProducers
                        )
                        
                        // Singers/Artists
                        AppFormField(
                            title: "Singers/Artists (comma separated)",
                            placeholder: "Singers/Artists",
                            text: $singers,
                            errorMessage: singers.isEmpty ? "At least one singer is required" : nil
                        )
                        
                        // Date and time
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date and Time")
                                .font(.headline)
                                .foregroundColor(.appTextPrimary)
                            
                            DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.graphical)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                        
                        // Duration
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Duration: \(Int(duration / 60)) hours \(Int(duration.truncatingRemainder(dividingBy: 60))) minutes")
                                .font(.headline)
                                .foregroundColor(.appTextPrimary)
                            
                            Slider(value: $duration, in: 60...360, step: 30)
                                .tint(.appPrimary)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                    
                    // Book button
                    Button(action: bookSession) {
                        Text("Book Session")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                    .disabled(!isFormValid || isLoading)
                }
            }
            .background(Color.appBackground)
            .alert("Booking Successful", isPresented: $showBookingSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your studio session has been booked successfully.")
            }
            .withLoading(isLoading: isLoading, message: "Booking session...")
            .onChange(of: appState.sessionManager.sessionError) { oldError, newError in
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
    
    private var studioSelection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Studio.allCases) { studio in
                    VStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedStudio == studio ? Color.appPrimary.opacity(0.1) : Color.white)
                                .frame(width: 140, height: 140)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(selectedStudio == studio ? Color.appPrimary : Color.gray.opacity(0.3), lineWidth: selectedStudio == studio ? 2 : 1)
                                )
                            
                            VStack {
                                Image(systemName: "music.mic")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(selectedStudio == studio ? .appPrimary : .gray)
                                
                                Text(studio.rawValue)
                                    .font(.headline)
                                    .foregroundColor(selectedStudio == studio ? .appPrimary : .primary)
                            }
                        }
                    }
                    .onTapGesture {
                        selectedStudio = studio
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var isFormValid: Bool {
        !mainProducer.isEmpty && !singers.isEmpty
    }
    
    private func bookSession() {
        guard isFormValid else { return }
        
        isLoading = true
        
        let additionalProducersList = additionalProducers.isEmpty 
            ? [] 
            : additionalProducers.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        
        let singersList = singers.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        
        let success = appState.sessionManager.bookSession(
            studio: selectedStudio,
            mainProducer: mainProducer,
            additionalProducers: additionalProducersList,
            singers: singersList,
            date: selectedDate,
            duration: duration
        )
        
        if success {
            isLoading = false
            showBookingSuccessAlert = true
            resetForm()
        } else if appState.sessionManager.sessionError == nil {
            // If there's no specific error set but booking failed
            isLoading = false
            errorMessage = "Failed to book session. Please try again."
            showError = true
        }
        // Otherwise, the onChange handler will catch the specific error
    }
    
    private func resetForm() {
        // Reset form fields after successful booking
        selectedStudio = .studioA
        mainProducer = ""
        additionalProducers = ""
        singers = ""
        selectedDate = Date()
        duration = 180
    }
}

// View extension for placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            self
            placeholder().opacity(shouldShow ? 1 : 0)
                .padding(.leading, 16)
        }
    }
}

#Preview {
    BookSessionView()
        .environmentObject(AppState())
} 