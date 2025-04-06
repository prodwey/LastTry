import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var backgroundColor: Color = .appPrimary
    var foregroundColor: Color = .white
    var cornerRadius: CGFloat = 8
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(configuration.isPressed ? backgroundColor.opacity(0.8) : backgroundColor)
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var foregroundColor: Color = .appPrimary
    var borderColor: Color = .appPrimary
    var cornerRadius: CGFloat = 8
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .foregroundColor(configuration.isPressed ? foregroundColor.opacity(0.8) : foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct DangerButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 8
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(configuration.isPressed ? Color.red.opacity(0.8) : Color.red)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ButtonStyle_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Button("Primary Button") {
                // Action
            }
            .buttonStyle(PrimaryButtonStyle())
            
            Button("Secondary Button") {
                // Action
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Button("Danger Button") {
                // Action
            }
            .buttonStyle(DangerButtonStyle())
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 