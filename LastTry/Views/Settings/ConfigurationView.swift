import SwiftUI

struct ConfigurationView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingPasswordSheet = false
    @State private var showingLogoutAlert = false
    
    // For editing user details
    @State private var name = ""
    @State private var email = ""
    @State private var isEditingProfile = false
    @State private var dateOfBirth = Date()
    @State private var role = UserRole.artist
    @State private var showingDatePicker = false
    
    // For success/error alerts
    @State private var showSaveSuccessAlert = false
    @State private var showSaveErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    // Date formatter for displaying date of birth
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Welcome header
                    if let user = appState.userManager.currentUser {
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.appPrimary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Hello, \(user.name)")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundColor(.black)
                                        .padding(.leading, 10)
                                }
                                
                                Spacer()
                                
                                Text(user.role.rawValue)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(UIColor.darkGray))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Language settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LANGUAGE")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                            .padding(.leading, 16)
                        
                        VStack(spacing: 0) {
                            ForEach(AppLanguage.allCases) { language in
                                Button(action: {
                                    appState.switchLanguage(to: language)
                                }) {
                                    HStack {
                                        Text(language.rawValue)
                                            .font(.system(size: 16))
                                            .foregroundColor(.black)
                                        
                                        Spacer()
                                        
                                        if appState.selectedLanguage == language {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.appPrimary)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                
                                if language != AppLanguage.allCases.last {
                                    Divider()
                                        .padding(.leading, 16)
                                        .background(Color.white)
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Account settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ACCOUNT")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                            .padding(.leading, 16)
                        
                        if let user = appState.userManager.currentUser {
                            if isEditingProfile {
                                // Edit mode
                                VStack(spacing: 16) {
                                    TextField("Name", text: $name)
                                        .padding()
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(8)
                                        .foregroundColor(.black)
                                    
                                    TextField("Email", text: $email)
                                        .padding()
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(8)
                                        .foregroundColor(.black)
                                    
                                    HStack {
                                        Text("Date of Birth")
                                            .foregroundColor(.black)
                                        
                                        Spacer()
                                        
                                        Text(dateFormatter.string(from: dateOfBirth))
                                            .foregroundColor(.appPrimary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        showingDatePicker = true
                                    }
                                    
                                    HStack {
                                        Text("Role")
                                            .foregroundColor(.black)
                                        
                                        Spacer()
                                        
                                        Menu {
                                            ForEach(UserRole.allCases) { role in
                                                Button(role.rawValue) {
                                                    self.role = role
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(role.rawValue)
                                                    .foregroundColor(.appPrimary)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .foregroundColor(.appPrimary)
                                                    .font(.system(size: 12))
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(8)
                                    
                                    HStack {
                                        Button("Save") {
                                            isSaving = true
                                            // Add a slight delay to show loading state
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                saveUserProfile()
                                                isSaving = false
                                                isEditingProfile = false
                                            }
                                        }
                                        .buttonStyle(PrimaryButtonStyle())
                                        .disabled(isSaving)
                                        .overlay(
                                            Group {
                                                if isSaving {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                }
                                            }
                                        )
                                        
                                        Button("Cancel") {
                                            resetForm(with: user)
                                            isEditingProfile = false
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                        .disabled(isSaving)
                                    }
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            } else {
                                // View mode in white card background
                                VStack(spacing: 0) {
                                    // Edit Profile button
                                    Button(action: {
                                        resetForm(with: user)
                                        isEditingProfile = true
                                    }) {
                                        HStack {
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 18))
                                            
                                            Text("Edit Profile")
                                                .font(.system(size: 16))
                                                .foregroundColor(.black)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .contentShape(Rectangle())
                                    }
                                    
                                    Divider()
                                        .padding(.leading, 16)
                                        .background(Color.white)
                                    
                                    // Change Password button
                                    Button(action: {
                                        showingPasswordSheet = true
                                    }) {
                                        HStack {
                                            Image(systemName: "lock.fill")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 18))
                                            
                                            Text("Change Password")
                                                .font(.system(size: 16))
                                                .foregroundColor(.black)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .contentShape(Rectangle())
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Logout button
                    Button(action: {
                        showingLogoutAlert = true
                    }) {
                        Text("Log Out")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.appPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    #if DEBUG
                    // Debug option to reset user data (only in debug mode)
                    Button(action: {
                        // Reset to factory defaults
                        appState.userManager.resetUserData()
                    }) {
                        Text("Reset User Data (Debug)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                    }
                    #endif
                    
                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("Settings")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showingPasswordSheet) {
            PasswordChangeView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerView(date: $dateOfBirth)
        }
        .alert("Log Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                appState.userManager.logout()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
        .alert("Profile Updated", isPresented: $showSaveSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your profile has been updated successfully.")
        }
        .alert("Error", isPresented: $showSaveErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func resetForm(with user: User) {
        name = user.name
        email = user.email
        dateOfBirth = user.dateOfBirth
        role = user.role
    }
    
    private func saveUserProfile() {
        // Validate user input
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Name cannot be empty."
            showSaveErrorAlert = true
            return
        }
        
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isValidEmail(email) {
            errorMessage = "Please enter a valid email address."
            showSaveErrorAlert = true
            return
        }
        
        // Check if user is too young (e.g., must be at least 13 years old)
        let calendar = Calendar.current
        let today = Date()
        let minimumAge = 13
        
        if let birthDate = calendar.date(byAdding: .year, value: -minimumAge, to: today),
           dateOfBirth > birthDate {
            errorMessage = "You must be at least \(minimumAge) years old."
            showSaveErrorAlert = true
            return
        }
        
        // If validation passes, update the profile
        let success = appState.userManager.updateUserProfile(
            name: name,
            email: email,
            dateOfBirth: dateOfBirth,
            role: role
        )
        
        if success {
            showSaveSuccessAlert = true
        } else {
            errorMessage = "Failed to update profile. Please try again."
            showSaveErrorAlert = true
        }
    }
    
    // Email validation helper
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

struct PasswordChangeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    @State private var errorMessage = ""
    @State private var isChanging = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Current Password").foregroundColor(.black)) {
                    SecureField("Current Password", text: $currentPassword)
                        .foregroundColor(.black)
                }
                
                Section(header: Text("New Password").foregroundColor(.black)) {
                    SecureField("New Password", text: $newPassword)
                        .foregroundColor(.black)
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .foregroundColor(.black)
                }
                
                Section {
                    Button("Change Password") {
                        isChanging = true
                        // Add a slight delay to show loading state
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            changePassword()
                            isChanging = false
                        }
                    }
                    .disabled(!isFormValid || isChanging)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(isFormValid && !isChanging ? .appPrimary : .gray)
                    .overlay(
                        Group {
                            if isChanging {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .appPrimary))
                            }
                        }
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your password has been updated successfully.")
            }
        }
    }
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty && newPassword == confirmPassword
    }
    
    private func changePassword() {
        // In a real app, this would validate the current password and update it on the server
        if newPassword != confirmPassword {
            errorMessage = "New passwords don't match."
            showingErrorAlert = true
            return
        }
        
        // Validate password requirements
        if newPassword.count < 8 {
            errorMessage = "Password must be at least 8 characters."
            showingErrorAlert = true
            return
        }
        
        // Clear any previous errors in the authentication service
        appState.authService.clearError()
        
        Task {
            // Use the AuthenticationService through UserManager for password updates
            let success = await withCheckedContinuation { continuation in
                Task {
                    let result = await appState.authService.updatePassword(
                        currentPassword: currentPassword,
                        newPassword: newPassword
                    )
                    
                    switch result {
                    case .success:
                        continuation.resume(returning: true)
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.errorMessage = error.localizedDescription
                        }
                        continuation.resume(returning: false)
                    }
                }
            }
            
            DispatchQueue.main.async {
                if success {
                    self.showingSuccessAlert = true
                } else {
                    self.showingErrorAlert = true
                }
            }
        }
    }
}

struct DatePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var date: Date
    @State private var selectedDate: Date
    
    init(date: Binding<Date>) {
        self._date = date
        self._selectedDate = State(initialValue: date.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .accentColor(.appPrimary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        date = selectedDate
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
    }
}

#Preview {
    ConfigurationView()
        .environmentObject({
            let state = AppState()
            state.loadDemoData()
            return state
        }())
        .preferredColorScheme(.dark)
}

