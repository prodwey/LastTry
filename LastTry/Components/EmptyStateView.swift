import SwiftUI

struct EmptyStateView: View {
    var icon: String
    var title: String
    var message: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.appTextSecondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.appTextPrimary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                Button(action: buttonAction) {
                    Text(buttonTitle)
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
}

struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            EmptyStateView(
                icon: "music.note.list",
                title: "No Songs Found",
                message: "You haven't uploaded any songs yet. Start by uploading your first track.",
                buttonTitle: "Upload Song",
                buttonAction: {}
            )
        }
        .previewLayout(.sizeThatFits)
    }
} 