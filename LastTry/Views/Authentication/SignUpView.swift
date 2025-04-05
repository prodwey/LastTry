import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var dateOfBirth = Date()
    @State private var selectedRole = UserRole.artist
    
    @State private var showPasswordMismatchAlert = false
    @State private var showDatePicker = false
    @State private var showEmptyFieldsAlert = false
    @State private var showInvalidEmailAlert = false
    @State private var showAuthErrorAlert = false
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        HeadingText(text: "Create Your Account")
                        BodyText(text: "Join Studio Manager to streamline your music production")
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    
                    // Form fields
                    VStack(spacing: 16) {
                        // Name
                        AppTextField(title: "Name", placeholder: "Enter your name", text: $name)
                        
                        // Email
                        AppTextField(title: "Email", placeholder: "Enter your email", text: $email)
                        
                        // Password
                        AppTextField(title: "Password", placeholder: "Enter your password", text: $password, isSecure: true)
                        
                        // Confirm password
                        AppTextField(title: "Confirm Password", placeholder: "Re-enter your password", text: $confirmPassword, isSecure: true)
                        
                        // Date of Birth
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Date of Birth")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                showDatePicker.toggle()
                            }) {
                                HStack {
                                    Text(dateOfBirth.formatted(date: .long, time: .omitted))
                                        .foregroundColor(.appTextPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "calendar")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.appSurfaceBackground)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.appDivider, lineWidth: 1)
                                )
                            }
                        }
                        
                        if showDatePicker {
                            DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .padding()
                                .background(Color.appSurfaceBackground)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                        
                        // Role
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Role")
                                .font(.caption)
                                .foregroundColor(.appTextSecondary)
                            
                            Picker("Select your role", selection: $selectedRole) {
                                ForEach(UserRole.allCases) { role in
                                    Text(role.rawValue).tag(role)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Sign up button
                    Button("Create Account") {
                        signUp()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 280)
                    .padding(.top, 20)
                    .disabled(appState.authService.isLoading)
                    .overlay(
                        Group {
                            if appState.authService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    )
                    
                    // Back to login
                    Button("Already have an account? Log In") {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .padding()
            }
        }
        .navigationBarTitle("Sign Up", displayMode: .inline)
        .navigationBarBackButtonHidden(false)
        .alert("Passwords Don't Match", isPresented: $showPasswordMismatchAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please make sure your passwords match.")
        }
        .alert("Missing Information", isPresented: $showEmptyFieldsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please fill in all required fields.")
        }
        .alert("Invalid Email", isPresented: $showInvalidEmailAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enter a valid email address.")
        }
        .alert("Authentication Error", isPresented: $showAuthErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appState.authService.authError?.localizedDescription ?? "An unknown error occurred")
        }
        .onChange(of: appState.authService.authError) { error in
            showAuthErrorAlert = (error != nil)
        }
    }
    
    private func signUp() {
        // Validate input fields
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           password.isEmpty {
            showEmptyFieldsAlert = true
            return
        }
        
        // Validate email format
        if !isValidEmail(email) {
            showInvalidEmailAlert = true
            return
        }
        
        // Check passwords match
        if password != confirmPassword {
            showPasswordMismatchAlert = true
            return
        }
        
        // Proceed with Firebase sign up
        Task {
            await appState.authService.signUp(
                name: name,
                email: email,
                password: password,
                dateOfBirth: dateOfBirth,
                role: selectedRole
            )
            // The auth state listener will handle updating UI if successful
        }
    }
    
    // Email validation helper
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AppState())
    }
} 