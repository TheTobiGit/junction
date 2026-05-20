import SwiftUI
import AppKit
import JunctionCore

/// Paste any URL and see how Junction's pipeline would transform it: which
/// transformer fired, what changed, plus risk flags. Flat layout: just a
/// row of controls and a typographic result panel, no card chrome.
struct URLInspectorCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var input: String = ""
    @State private var trace: URLTransformResult? = nil
    @State private var flags: [RiskFlag] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            inputRow

            if let trace {
                results(for: trace)
            }
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField("Paste a URL…", text: $input, onCommit: inspect)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05))
                )

            Button {
                pasteAndInspect()
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Paste & inspect")

            Button {
                inspect()
            } label: {
                Text("Inspect")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .foregroundStyle(.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.07))
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if trace != nil {
                Button(action: clear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
    }

    private func results(for trace: URLTransformResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            kvRow("Original", trace.original.absoluteString)
            kvRow("Cleaned",  trace.final.absoluteString, accent: trace.didChange)

            if !trace.steps.isEmpty {
                Text("PIPELINE")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(trace.steps.enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(width: 16, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(URLPipelineStepLabel.label(for: step.identifier))
                                    .font(.system(size: 11, weight: .medium))
                                Text(step.after.absoluteString)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }
            } else {
                Text("No transformers fired — URL is already clean.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if !flags.isEmpty {
                Text("RISK")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(flags) { flag in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: RiskChip.icon(for: flag.level))
                                .foregroundStyle(RiskChip.tint(for: flag.level))
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 14)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(flag.title)
                                    .font(.system(size: 11, weight: .medium))
                                Text(flag.detail)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            let stripped = URLDiff.strippedTrackerParams(in: trace)
            if !stripped.isEmpty {
                Text("REMOVED PARAMS")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .padding(.top, 6)
                FlowLayout(spacing: 6) {
                    ForEach(stripped, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func kvRow(_ label: String, _ value: String, accent: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.secondary.opacity(0.7))
                .frame(width: 60, alignment: .leading)
                .padding(.top, 1)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(accent ? Color.accentColor : Color.primary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Copy")
        }
    }

    private func inspect() {
        var raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        if !raw.contains("://"), raw.contains(".") {
            raw = "https://" + raw
        }
        guard let url = URL(string: raw) else {
            trace = nil
            flags = []
            return
        }
        let result = URLTransformers.default.runTraced(url)
        trace = result
        flags = URLRiskAssessor.assess(result.final)
    }

    private func pasteAndInspect() {
        if let pasted = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !pasted.isEmpty {
            input = pasted
        }
        inspect()
    }

    private func clear() {
        input = ""
        trace = nil
        flags = []
    }
}
