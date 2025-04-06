import SwiftUI

// View modifier for displaying error messages
struct ErrorDisplayModifier: ViewModifier {
    let message: String
    let severity: DisplayErrorSeverity
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented {
                VStack {
                    Spacer()
                    
                    HStack(alignment: .top, spacing: 12) {
                        // Error icon
                        Image(systemName: severityIcon)
                            .foregroundColor(severityColor)
                            .font(.system(size: 20))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(.appTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        // Dismiss button
                        Button {
                            withAnimation(.easeInOut) {
                                isPresented = false
                            }
                            onDismiss?()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.appTextSecondary)
                        }
                        .padding(4)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.appElevatedBackground)
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal, 16)
                    .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                }
                .padding(.bottom, 16)
                .zIndex(100)
                .onAppear {
                    // Auto-dismiss after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        if isPresented {
                            withAnimation {
                                isPresented = false
                                onDismiss?()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Icon based on severity
    private var severityIcon: String {
        switch severity {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        case .critical:
            return "xmark.octagon.fill"
        }
    }
    
    // Color based on severity
    private var severityColor: Color {
        switch severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
}

// View modifier for displaying loading state
struct LoadingModifier: ViewModifier {
    let isLoading: Bool
    let message: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 3 : 0)
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.appPrimary)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appElevatedBackground.opacity(0.95))
                        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 4)
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: isLoading)
    }
}

// Extensions to make the modifiers easy to use
extension View {
    func withErrorDisplay(
        message: String,
        severity: DisplayErrorSeverity = .error,
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        self.modifier(ErrorDisplayModifier(
            message: message,
            severity: severity,
            isPresented: isPresented,
            onDismiss: onDismiss
        ))
    }
} 