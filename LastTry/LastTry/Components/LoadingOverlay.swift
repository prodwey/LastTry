import SwiftUI

struct LoadingOverlay: View {
    var isLoading: Bool
    var message: String?
    
    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    if let message = message {
                        Text(message)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appElevatedBackground.opacity(0.9))
                )
                .shadow(color: Color.black.opacity(0.2), radius: 8)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
    }
}

#Preview {
    VStack {
        Text("Sample Content")
            .padding()
    }
    .overlay(LoadingOverlay(isLoading: true, message: "Loading data..."))
} 