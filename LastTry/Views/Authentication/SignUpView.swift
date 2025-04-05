import SwiftUI
import FirebaseAuth

struct SignUpView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var role: UserRole = .artist
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSigningUp = false
    
    @State private var isDatePickerVisible = false
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        HeadingText(text: "Create Account")
                        BodyText(text: "Sign up to start managing your studio sessions")
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 32)
                    
                    // Form fields
                    VStack(spacing: 24) {
                        // Name
                        AppTextField(title: "Full Name", placeholder: "Enter your name", text: $name)
                        
                        // Email
                        AppTextField(title: "Email", placeholder: "Enter your email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        // Password
                        AppTextField(title: "Password", placeholder: "Create a password", text: $password, isSecure: true)
                        
                        // Confirm Password
                        AppTextField(title: "Confirm Password", placeholder: "Confirm your password", text: $confirmPassword, isSecure: true)
                        
                        // Date of Birth
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date of Birth")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appTextSecondary)
                            
                            Button {
                                isDatePickerVisible.toggle()
                            } label: {
                                HStack {
                                    Text(dateOfBirth.formatted(date: .long, time: .omitted))
                                        .foregroundColor(.appTextPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "calendar")
                                        .foregroundColor(.appTextSecondary)
                                }
                                .padding()
                                .background(Color.appElevatedBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appDivider, lineWidth: 1)
                                )
                            }
                            
                            if isDatePickerVisible {
                                DatePicker(
                                    "Select your date of birth",
                                    selection: $dateOfBirth,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(GraphicalDatePickerStyle())
                                .frame(maxHeight: 400)
                                .padding()
                                .background(Color.appElevatedBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appDivider, lineWidth: 1)
                                )
                            }
                        }
                        
                        // Role selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("I am a...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.appTextSecondary)
                            
                            HStack(spacing: 12) {
                                ForEach(UserRole.allCases.filter { $0 != .admin }) { userRole in
                                    Button {
                                        role = userRole
                                    } label: {
                                        Text(userRole.rawValue)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(role == userRole ? .white : .appTextPrimary)
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 16)
                                            .frame(maxWidth: .infinity)
                                            .background(role == userRole ? Color.appPrimary : Color.appElevatedBackground)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.appDivider, lineWidth: role == userRole ? 0 : 1)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Sign up button
                    Button {
                        signUp()
                    } label: {
                        if isSigningUp {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Create Account")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 280)
                    .padding(.top, 32)
                    .disabled(name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty || isSigningUp)
                    
                    // Login option
                    Button("Already have an account? Log In") {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarTitle("Sign Up", displayMode: .inline)
        .navigationBarBackButtonHidden(false)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: appState.userManager.authError) { newError in
            if let error = newError {
                errorMessage = error
                showError = true
                isSigningUp = false
            }
        }
        .onChange(of: appState.isAuthenticated) { isAuthenticated in
            print("SignUpView: App authentication state changed to \(isAuthenticated)")
            if isAuthenticated {
                isSigningUp = false
            }
        }
    }
    
    private func signUp() {
        // Validate inputs
        guard !name.isEmpty else {
            errorMessage = "Please enter your name"
            showError = true
            return
        }
        
        guard !email.isEmpty, email.contains("@") else {
            errorMessage = "Please enter a valid email address"
            showError = true
            return
        }
        
        guard !password.isEmpty, password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            showError = true
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            showError = true
            return
        }
        
        // Check age
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        guard let age = ageComponents.year, age >= 13 else {
            errorMessage = "You must be at least 13 years old to create an account"
            showError = true
            return
        }
        
        isSigningUp = true
        
        // Create account
        appState.userManager.signUp(
            name: name,
            email: email,
            password: password,
            dateOfBirth: dateOfBirth,
            role: role
        )
        
        // Auth state will be handled by listeners
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AppState())
    }
} 