import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    // Get services from ServiceLocator
    private let authService = ServiceLocator.shared.resolve(AuthenticationServiceProtocol.self)
    private let userManager = ServiceLocator.shared.resolve(UserManagerProtocol.self)
    
    @State private var email = ""
    @State private var password = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isLoggingIn = false
    @State private var showAuthManagerDemo = false
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    HeadingText(text: "Welcome Back")
                    BodyText(text: "Log in to your Studio Manager account")
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                
                // Form fields
                VStack(spacing: 20) {
                    // Email
                    AppTextField(title: "Email", placeholder: "Enter your email", text: $email)
                    
                    // Password
                    AppTextField(title: "Password", placeholder: "Enter your password", text: $password, isSecure: true)
                    
                    // Forgot password
                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            if !email.isEmpty {
                                sendPasswordReset()
                            } else {
                                errorMessage = "Please enter your email address first"
                                showErrorAlert = true
                            }
                        }
                        .foregroundColor(.appPrimary)
                        .font(.caption)
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
                .padding(.top, 40)
                .disabled(email.isEmpty || password.isEmpty || isLoggingIn)
                
                // Sign up option
                Button("Don't have an account? Sign Up") {
                    dismiss()
                }
                .foregroundColor(.appPrimary)
                .padding(.top, 8)
                
                Spacer()
                
                // Demo Button
                Button("Try New Authentication Demo") {
                    showAuthManagerDemo = true
                }
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 20)
            }
            .padding()
        }
        .navigationBarTitle("Log In", displayMode: .inline)
        .navigationBarBackButtonHidden(false)
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showAuthManagerDemo) {
            AuthManagerDemoView()
        }
        .withLoading(isLoading: isLoggingIn, message: "Logging in...")
        .onChange(of: userManager?.authError) { _, newError in
            if let error = newError {
                errorMessage = error.localizedDescription
                showErrorAlert = true
                isLoggingIn = false
            }
        }
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            print("LoginView: App authentication state changed to \(isAuthenticated)")
            if isAuthenticated {
                isLoggingIn = false
            }
        }
        .onChange(of: authService?.authError) { _, newError in
            if let error = newError {
                errorMessage = error.localizedDescription
                showErrorAlert = true
                isLoggingIn = false
            }
        }
    }
    
    private func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password"
            showErrorAlert = true
            return
        }
        
        isLoggingIn = true
        
        // Clear any previous errors
        authService?.clearError()
        
        // Attempt login using the UserManager
        print("LoginView: Attempting to log in with email: \(email)")
        userManager?.login(email: email, password: password)
        
        // Auth state will be handled by listeners
    }
    
    private func sendPasswordReset() {
        // Use our AuthenticationService instead of Firebase Auth directly
        startPasswordResetProcess(email: email)
    }
    
    // Helper method to perform password reset request asynchronously
    private func startPasswordResetProcess(email: String) {
        // Using runAsync helper instead of ConcurrencyTask
        runAsync {
            // Clear any previous errors
            await runOnMainActor {
                self.authService?.clearError()
            }
            
            let result = await self.authService?.resetPassword(for: email) ?? .failure(AuthError.unknown)
            
            // Update UI on main thread
            await runOnMainActor {
                switch result {
                case .success:
                    self.errorMessage = "Password reset email sent. Please check your inbox."
                    self.showErrorAlert = true
                case .failure(let error):
                    self.errorMessage = "Could not send password reset: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AppState())
    }
} 