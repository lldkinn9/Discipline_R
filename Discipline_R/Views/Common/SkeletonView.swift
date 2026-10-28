import SwiftUI

struct SkeletonView: View {
    @State private var isAnimating = false
    var height: CGFloat = 20
    var cornerRadius: CGFloat = 6
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color(white: 0.12),
                        Color(white: 0.22),
                        Color(white: 0.12)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: height)
            .mask(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white)
            )
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

