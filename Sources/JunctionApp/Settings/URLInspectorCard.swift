import SwiftUI
import AppKit
import JunctionCore

/// Lets the user paste any URL and see exactly how Junction's pipeline would
/// transform it: which transformer fired, what each one changed, plus the
/// risk flags that would be raised. Useful for diagnosing "why did Junction
/// strip ref=…" questions.
struct URLInspectorCard: View {
    @State private var input: String = ""
    @State private var trace: URLTransformResult? = nil
    @State private var flags: [RiskFlag] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Inspect a URL")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Paste any link to see how Junction would clean and assess it.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if trace != nil {
                    Button {
                        clear()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                TextField("https://…", text: $input, onCommit: inspect)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                Button {
                    pasteAndInspect()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .help("Paste from clipboard and inspect")
                .controlSize(.small)
                Button("Inspect") { inspect() }
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let trace {
                VStack(alignment: .leading, spacing: 10) {
                    resultRow(label: "Original", value: trace.original.absoluteString, monospaced: true)
                    resultRow(
                        label: "Cleaned",
                        value: trace.final.absoluteString,
                        monospaced: true,
                        accent: trace.didChange
                    )
                    if !trace.steps.isEmpty {
                        Text("Pipeline steps")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(trace.steps.enumerated()), id: \.offset) { idx, step in
                                stepRow(index: idx + 1, step: step)
                            }
                        }
                    } else {
                        Text("No transformers fired — URL is already clean.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    if !flags.isEmpty {
                        Text("Risk flags")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(flags) { flag in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: RiskChip.icon(for: flag.level))
                                        .foregroundColor(RiskChip.tint(for: flag.level))
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(width: 14)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(flag.title)
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(flag.detail)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    let stripped = URLDiff.strippedTrackerParams(in: trace)
                    if !stripped.isEmpty {
                        Text("Removed query parameters")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        FlowLayout(spacing: 6) {
                            ForEach(stripped, id: \.self) { name in
                                Text(name)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            }
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
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

    private func resultRow(label: String, value: String, monospaced: Bool, accent: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: monospaced ? .monospaced : .default))
                .foregroundColor(accent ? .accentColor : .primary)
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
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Copy")
        }
    }

    private func stepRow(index: Int, step: URLTransformResult.Step) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.accentColor)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor.opacity(0.18)))
            VStack(alignment: .leading, spacing: 1) {
                Text(URLPipelineStepLabel.label(for: step.identifier))
                    .font(.system(size: 11, weight: .semibold))
                Text(step.after.absoluteString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}
