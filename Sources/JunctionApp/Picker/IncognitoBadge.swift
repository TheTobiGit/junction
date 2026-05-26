import SwiftUI

struct IncognitoBadge: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.78))
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                )
            Image(systemName: "eyeglasses")
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
    }
}
