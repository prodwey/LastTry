import SwiftUI
import FirebaseAuth

extension LoginView {
    
    /// A demonstration view showing how to use the AuthenticationManager without AppState
    struct AuthManagerDemoView: View {
        @State private var email = ""
        @State private var password = ""
        @State private var showErrorAlert = false
        @State private var errorMessage = ""
        @State private var isLoggingIn = false
        @State private var isAuthenticated = false
        
        // Track authentication state changes
        @State private var authStateObserver: NSObjectProtocol? = nil
        
        var body: some View {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Authentication Demo")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Using AuthenticationManager")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    
                    // Status
                    HStack {
                        Text("Auth Status:")
                            .foregroundColor(.white)
                        
                        Text(isAuthenticated ? "Logged In" : "Not Logged In")
                            .foregroundColor(isAuthenticated ? .green : .red)
                            .fontWeight(.bold)
                    }
                    .padding(.bottom, 20)
                    
                    // Form fields
                    if !isAuthenticated {
                        VStack(spacing: 20) {
                            // Email
                            AppTextField(title: "Email", placeholder: "Enter your email", text: $email)
                            
                            // Password
                            AppTextField(title: "Password", placeholder: "Enter your password", text: $password, isSecure: true)
                            
                            // Forgot password
                            HStack {
                                Spacer()
                                Button("Forgot Password?") {
                                    sendPasswordReset()
                                }
                                .foregroundColor(.appPrimary)
                                .font(.caption)
                                .disabled(email.isEmpty)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Login button
                        Button {
                            login()
                        } label: {
                            Text("Log In")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 280)
                        .padding(.top, 20)
                        .disabled(email.isEmpty || password.isEmpty || isLoggingIn)
                    } else {
                        // Logout button
                        Button {
                            logout()
                        } label: {
                            Text("Log Out")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: 280)
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Message"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .withLoading(isLoading: isLoggingIn, message: "Processing...")
            .onAppear {
                // Check current auth state
                updateAuthState()
                
                // Listen for auth state changes via notifications
                authStateObserver = NotificationCenter.default.addObserver(
                    forName: .passwordResetEmailSent,
                    object: nil,
                    queue: .main
                ) { _ in
                    errorMessage = "Password reset email sent. Please check your inbox."
                    showErrorAlert = true
                }
            }
            .onDisappear {
                // Remove observer when view disappears
                if let observer = authStateObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        }
        
        private func updateAuthState() {
            // Get authentication state directly from AuthenticationManager
            isAuthenticated = AuthenticationManager.isAuthenticated
            
            if isAuthenticated, let user = AuthenticationManager.currentUser {
                print("User is logged in: \(user.email ?? "unknown")")
            } else {
                print("No user is logged in")
            }
        }
        
        private func login() {
            guard !email.isEmpty, !password.isEmpty else {
                errorMessage = "Please enter both email and password"
                showErrorAlert = true
                return
            }
            
            isLoggingIn = true
            
            // Using AuthenticationManager without requiring AppState
            runAsync {
                let result = await AuthenticationManager.signIn(email: email, password: password)
                
                await runOnMainActor {
                    isLoggingIn = false
                    
                    switch result {
                    case .success(let user):
                        // Success case - update state
                        email = ""
                        password = ""
                        updateAuthState()
                        
                        errorMessage = "Successfully logged in as \(user.email ?? "user")"
                        showErrorAlert = true
                        
                    case .failure(let error):
                        // Error case - show alert
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                }
            }
        }
        
        private func logout() {
            // Using AuthenticationManager without requiring AppState
            let result = AuthenticationManager.signOut()
            
            switch result {
            case .success:
                updateAuthState()
            case .failure(let error):
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
        
        private func sendPasswordReset() {
            guard !email.isEmpty else {
                errorMessage = "Please enter your email address first"
                showErrorAlert = true
                return
            }
            
            isLoggingIn = true
            
            // Using AuthenticationManager without requiring AppState
            runAsync {
                let result = await AuthenticationManager.resetPassword(for: email)
                
                await runOnMainActor {
                    isLoggingIn = false
                    
                    if case .failure(let error) = result {
                        errorMessage = "Could not send password reset: \(error.localizedDescription)"
                        showErrorAlert = true
                    }
                    // Success case is handled via notification
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView.AuthManagerDemoView()
    }
} 