import SwiftUI

/// A SwiftUI view for displaying a loading overlay
struct LoadingOverlayView: View {
    var body: some View {
        Color.black.opacity(0.5)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            )
    }
}
