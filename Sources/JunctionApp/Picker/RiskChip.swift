import SwiftUI

/// Compact risk chip for the picker header. Tap to expand into a popover that
/// lists every active flag with its detail, instead of cramming everything
/// into a tooltip.
struct RiskChip: View {
    let flags: [RiskFlag]
    @State private var isExpanded: Bool = false

    private var highest: RiskFlag {
        flags.max(by: { $0.level.rawValue < $1.level.rawValue }) ?? flags[0]
    }

    private var tint: Color { Self.tint(for: highest.level) }
    private var extra: Int { max(flags.count - 1, 0) }

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: Self.icon(for: highest.level))
                    .font(.system(size: 11, weight: .semibold))
                Text(highest.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if extra > 0 {
                    Text("+\(extra)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(tint)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(tint.opacity(0.28)))
                }
            }
            .foregroundColor(tint)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.18)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
            popoverBody
                .padding(14)
                .frame(width: 320)
        }
        .help("Click for details")
    }

    private var popoverBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: Self.icon(for: highest.level))
                    .foregroundColor(tint)
                Text("\(flags.count) " + (flags.count == 1 ? "risk flag" : "risk flags"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            ForEach(flags.sorted { $0.level.rawValue > $1.level.rawValue }) { flag in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: Self.icon(for: flag.level))
                        .foregroundColor(Self.tint(for: flag.level))
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(flag.title)
                            .font(.system(size: 12, weight: .semibold))
                        Text(flag.detail)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    static func tint(for level: RiskLevel) -> Color {
        switch level {
        case .info: return .blue
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }

    static func icon(for level: RiskLevel) -> String {
        switch level {
        case .info: return "info.circle.fill"
        case .low: return "exclamationmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "shield.lefthalf.filled"
        }
    }
}
