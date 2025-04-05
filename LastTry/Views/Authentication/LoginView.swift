import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var showInvalidCredentialsAlert = false
    
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
                            // Would normally navigate to password reset
                        }
                        .foregroundColor(.appPrimary)
                        .font(.caption)
                    }
                }
                .padding(.horizontal, 20)
                
                // Login button
                Button("Log In") {
                    appState.userManager.login(email: email, password: password)
                    
                    if !appState.userManager.isLoggedIn {
                        showInvalidCredentialsAlert = true
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 280)
                .padding(.top, 40)
                
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
        .alert("Invalid Credentials", isPresented: $showInvalidCredentialsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please check your email and password and try again.")
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AppState())
    }
} 