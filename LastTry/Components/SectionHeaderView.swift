import SwiftUI

struct SectionHeaderView: View {
    var title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.appTextPrimary)
            
            Spacer()
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appPrimary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct SectionHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                SectionHeaderView(title: "Recently Played")
                
                SectionHeaderView(
                    title: "My Songs",
                    actionTitle: "See All",
                    action: {}
                )
            }
        }
        .previewLayout(.sizeThatFits)
    }
} 