import SwiftUI

struct FormFieldWithError: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var errorMessage: String?
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.appTextPrimary)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .padding()
                    .background(Color.appElevatedBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(errorMessage != nil ? Color.red : Color.appDivider, lineWidth: 1)
                    )
                    .textInputAutocapitalization(autocapitalization)
                    .keyboardType(keyboardType)
            } else {
                TextField(placeholder, text: $text)
                    .padding()
                    .background(Color.appElevatedBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(errorMessage != nil ? Color.red : Color.appDivider, lineWidth: 1)
                    )
                    .textInputAutocapitalization(autocapitalization)
                    .keyboardType(keyboardType)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 4)
                    .transition(.opacity)
            }
        }
    }
}

struct FormFieldWithError_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            FormFieldWithError(
                title: "Username",
                placeholder: "Enter your username",
                text: .constant(""),
                errorMessage: nil
            )
            
            FormFieldWithError(
                title: "Password",
                placeholder: "Enter your password",
                text: .constant(""),
                errorMessage: "Password must be at least 8 characters",
                isSecure: true
            )
        }
        .padding()
        .background(Color.appBackground)
        .previewLayout(.sizeThatFits)
    }
} 