import SwiftUI

// MARK: - Color Extensions
extension Color {
    // Main theme colors
    static let appPrimary = Color(red: 1.0, green: 0.18, blue: 0.18) // YouTube Music red
    static let appSecondary = Color(red: 0.15, green: 0.15, blue: 0.15) // Dark gray for cards
    
    // Background colors
    static let appBackground = Color(red: 0.07, green: 0.07, blue: 0.07) // Almost black
    static let appSurfaceBackground = Color(red: 0.11, green: 0.11, blue: 0.11) // Card backgrounds
    static let appElevatedBackground = Color(red: 0.15, green: 0.15, blue: 0.15) // Elevated components
    
    // Text colors
    static let appTextPrimary = Color.white
    static let appTextSecondary = Color(white: 0.7)
    static let appTextTertiary = Color(white: 0.5)
    
    // Utility colors
    static let appSuccess = Color.green
    static let appWarning = Color.orange
    static let appError = Color.red
    static let appDivider = Color(white: 0.2)
}

// MARK: - Text Styles
struct TitleText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.appTextPrimary)
    }
}

struct HeadingText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.appTextPrimary)
    }
}

struct SubheadingText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.title3)
            .fontWeight(.medium)
            .foregroundColor(.appTextPrimary)
    }
}

struct BodyText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.body)
            .foregroundColor(.appTextPrimary)
    }
}

struct CaptionText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.appTextSecondary)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.appPrimary)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.appTextPrimary)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.appElevatedBackground)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.appTextPrimary)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.appDivider, lineWidth: 1)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - Card Styles
struct MediaCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.appSurfaceBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Input Styles
struct AppTextField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    @State private var isPasswordVisible: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.appTextSecondary)
            
            if isSecure {
                HStack {
                    if isPasswordVisible {
                        TextField(placeholder, text: $text)
                            .autocorrectionDisabled(true)
                            .textContentType(.oneTimeCode) // Prevents password autofill
                            .foregroundColor(.appTextPrimary)
                    } else {
                        SecureField(placeholder, text: $text)
                            .textContentType(.oneTimeCode) // Prevents password autofill
                            .foregroundColor(.appTextPrimary)
                    }
                    
                    // Toggle password visibility button
                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .padding()
                .background(Color.appSurfaceBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appDivider, lineWidth: 1)
                )
            } else {
                TextField(placeholder, text: $text)
                    .padding()
                    .background(Color.appSurfaceBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appDivider, lineWidth: 1)
                    )
            }
        }
        .foregroundColor(.appTextPrimary)
    }
}

// MARK: - Tab Styles
struct CustomTabStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(height: 50)
            .background(Color.appBackground)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.appDivider),
                alignment: .top
            )
    }
}

// MARK: - Navigation Bar Styles
struct CustomNavigationBar: ViewModifier {
    var title: String
    
    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - View Modifiers
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    func withMediaCard() -> some View {
        modifier(MediaCard())
    }
    
    func withCustomNavBar(title: String) -> some View {
        modifier(CustomNavigationBar(title: title))
    }
    
    func withCustomTabBar() -> some View {
        modifier(CustomTabStyle())
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    var icon: String
    var title: String
    var message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 70))
                .foregroundColor(.appTextSecondary)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.appTextPrimary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Priority Badge
struct PriorityBadge: View {
    var priority: TaskPriority
    
    var body: some View {
        Text(priority.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    private var priorityColor: Color {
        switch priority {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
} 