import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var showAuthErrorAlert = false
    @State private var showResetPasswordAlert = false
    @State private var resetEmailSent = false
    
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
                            if email.isEmpty {
                                // Show alert to enter email first
                                showResetPasswordAlert = true
                            } else {
                                sendPasswordReset()
                            }
                        }
                        .foregroundColor(.appPrimary)
                        .font(.caption)
                    }
                }
                .padding(.horizontal, 20)
                
                // Login button
                Button("Log In") {
                    login()
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 280)
                .padding(.top, 40)
                .disabled(appState.authService.isLoading)
                .overlay(
                    Group {
                        if appState.authService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                )
                
                // Sign up option
                Button("Don't have an account? Sign Up") {
                    dismiss()
                }
                .foregroundColor(.appPrimary)
                .padding(.top, 8)
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitle("Log In", displayMode: .inline)
        .navigationBarBackButtonHidden(false)
        .alert("Authentication Error", isPresented: $showAuthErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appState.authService.authError?.localizedDescription ?? "Invalid credentials. Please try again.")
        }
        .alert("Password Reset", isPresented: $showResetPasswordAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Send") {
                sendPasswordReset()
            }
        } message: {
            if resetEmailSent {
                Text("Password reset email has been sent.")
            } else {
                Text("Please enter your email address to receive a password reset link.")
            }
        }
        .onChange(of: appState.authService.authError) { error in
            showAuthErrorAlert = (error != nil)
        }
    }
    
    private func login() {
        Task {
            await appState.authService.signIn(email: email, password: password)
            // The auth state listener will handle updating UI if successful
        }
    }
    
    private func sendPasswordReset() {
        Task {
            resetEmailSent = await appState.authService.sendPasswordReset(to: email)
            if resetEmailSent {
                showResetPasswordAlert = true
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