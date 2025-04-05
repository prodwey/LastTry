import SwiftUI

struct BookSessionView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var selectedStudio: Studio = .studioA
    @State private var mainProducer = ""
    @State private var additionalProducers = ""
    @State private var singers = ""
    @State private var selectedDate = Date()
    @State private var duration: Double = 180 // Default to 3 hours
    
    @State private var showBookingSuccessAlert = false
    @State private var showBookingFailedAlert = false
    @State private var bookingFailedMessage = ""
    
    var body: some View {
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Main Producer")
                            .font(.caption)
                            .foregroundColor(.appTextSecondary)
                        
                        TextField("", text: $mainProducer)
                            .padding()
                            .background(Color.appElevatedBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.appDivider, lineWidth: 1)
                            )
                            .foregroundColor(.appTextPrimary)
                            .placeholder(when: mainProducer.isEmpty) {
                                Text("Producer Name")
                                    .foregroundColor(.appTextSecondary)
                            }
                    }
                    
                    // Additional producers
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Additional Producers (comma separated)")
                            .font(.caption)
                            .foregroundColor(.appTextSecondary)
                        
                        TextField("", text: $additionalProducers)
                            .padding()
                            .background(Color.appElevatedBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.appDivider, lineWidth: 1)
                            )
                            .foregroundColor(.appTextPrimary)
                            .placeholder(when: additionalProducers.isEmpty) {
                                Text("Additional Producers")
                                    .foregroundColor(.appTextSecondary)
                            }
                    }
                    
                    // Singers/Artists
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Singers/Artists (comma separated)")
                            .font(.caption)
                            .foregroundColor(.appTextSecondary)
                        
                        TextField("", text: $singers)
                            .padding()
                            .background(Color.appElevatedBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.appDivider, lineWidth: 1)
                            )
                            .foregroundColor(.appTextPrimary)
                            .placeholder(when: singers.isEmpty) {
                                Text("Singers/Artists")
                                    .foregroundColor(.appTextSecondary)
                            }
                    }
                    
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
                .disabled(!isFormValid)
            }
        }
        .background(Color.appBackground)
        .alert("Booking Successful", isPresented: $showBookingSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your studio session has been booked successfully.")
        }
        .alert("Booking Failed", isPresented: $showBookingFailedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(bookingFailedMessage)
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
            showBookingSuccessAlert = true
            resetForm()
        } else {
            bookingFailedMessage = "This studio is already booked for the selected time. Please choose a different time or studio."
            showBookingFailedAlert = true
        }
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