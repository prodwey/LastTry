import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var isSignUpActive = false
    @State private var isLoginActive = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // App logo
                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "music.note")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.white)
                        )
                        .padding(.bottom, 16)
                    
                    // App name and tagline
                    VStack(spacing: 8) {
                        Text("Studio Manager")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.appTextPrimary)
                        
                        Text("Streamline your music production")
                            .font(.system(size: 16))
                            .foregroundColor(.appTextSecondary)
                            .padding(.bottom, 24)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        // Sign up button
                        Button {
                            isSignUpActive = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("SIGN UP")
                                    .font(.system(size: 16, weight: .bold))
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .background(Color.appPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(24)
                        }
                        .frame(maxWidth: 280)
                        
                        // Login button
                        Button {
                            isLoginActive = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("LOG IN")
                                    .font(.system(size: 16, weight: .bold))
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .background(Color.appElevatedBackground)
                            .foregroundColor(.appTextPrimary)
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.appDivider, lineWidth: 1)
                            )
                        }
                        .frame(maxWidth: 280)
                    }
                    .padding(.bottom, 40)
                    
                    // Footer text
                    Text("© 2025 Studio Manager")
                        .font(.caption)
                        .foregroundColor(.appTextTertiary)
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 24)
                .navigationDestination(isPresented: $isSignUpActive) {
                    SignUpView()
                }
                .navigationDestination(isPresented: $isLoginActive) {
                    LoginView()
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
} 