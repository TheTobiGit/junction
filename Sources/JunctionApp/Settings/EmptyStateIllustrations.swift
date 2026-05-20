import SwiftUI

struct RulesEmptyIllustration: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 2, y: 2))
                    path.addLine(to: CGPoint(x: 58, y: 2))
                    path.addLine(to: CGPoint(x: 40, y: 26))
                    path.addLine(to: CGPoint(x: 40, y: 46))
                    path.addLine(to: CGPoint(x: 20, y: 46))
                    path.addLine(to: CGPoint(x: 20, y: 26))
                    path.closeSubpath()
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                .frame(width: 60, height: 48)

                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: 14, height: 14)
                    .offset(x: -12, y: 14)

                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: 14, height: 14)
                    .offset(x: 12, y: 14)

                Rectangle()
                    .fill(Color.accentColor.opacity(0.35))
                    .frame(width: 12, height: 3)
                    .cornerRadius(1.5)
                    .offset(x: -12, y: 14)

                Rectangle()
                    .fill(Color.accentColor.opacity(0.35))
                    .frame(width: 12, height: 3)
                    .cornerRadius(1.5)
                    .offset(x: 12, y: 14)
            }
            .frame(width: 60, height: 52)
        }
        .accessibilityIdentifier("rules-empty-illustration")
        .accessibilityHidden(true)
    }
}

struct ActivityEmptyIllustration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            activityRow(width: 44, opacity: 0.7)
            activityRow(width: 32, opacity: 0.5)
            activityRow(width: 52, opacity: 0.35)
        }
        .accessibilityIdentifier("activity-empty-illustration")
        .accessibilityHidden(true)
    }

    private func activityRow(width: CGFloat, opacity: Double) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.accentColor.opacity(opacity))
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(Color.accentColor.opacity(opacity * 0.6))
                .frame(width: width, height: 3)
                .cornerRadius(1.5)
        }
    }
}
