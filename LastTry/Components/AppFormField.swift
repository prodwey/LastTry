import SwiftUI

/// A wrapper around FormFieldWithError with a distinctive name 
/// to avoid ambiguity issues in the compiler
struct AppFormField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var errorMessage: String?
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    
    var body: some View {
        FormFieldWithError(
            title: title,
            placeholder: placeholder,
            text: $text,
            errorMessage: errorMessage,
            isSecure: isSecure,
            keyboardType: keyboardType,
            autocapitalization: autocapitalization
        )
    }
}

struct AppFormField_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AppFormField(
                title: "Username",
                placeholder: "Enter your username",
                text: .constant(""),
                errorMessage: nil
            )
            
            AppFormField(
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