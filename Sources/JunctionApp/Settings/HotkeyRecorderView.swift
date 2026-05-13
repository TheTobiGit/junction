import SwiftUI
import AppKit
import Carbon

struct HotkeyRowView: View {
    let title: String
    let detail: String
    @Binding var binding: HotkeyBinding

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            HotkeyRecorderView(binding: $binding)
                .frame(width: 140, height: 26)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var binding: HotkeyBinding

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.binding = binding
        view.onChange = { newValue in
            self.binding = newValue
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.binding = binding
        nsView.needsDisplay = true
    }
}

final class HotkeyRecorderNSView: NSView {
    var binding: HotkeyBinding = .none {
        didSet { needsDisplay = true }
    }
    var onChange: ((HotkeyBinding) -> Void)?

    private var recording: Bool = false {
        didSet { needsDisplay = true }
    }
    private var monitor: Any?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        recording.toggle()
        if recording { installMonitor() } else { removeMonitor() }
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        removeMonitor()
        return super.resignFirstResponder()
    }

    private func installMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    self.commit(binding: .none)
                    return nil
                }
                let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
                let carbonMods = HotkeyFormatting.cocoaModifiersToCarbon(mods)
                if carbonMods == 0 { return event }
                let newBinding = HotkeyBinding(
                    keyCode: UInt32(event.keyCode),
                    modifiers: carbonMods,
                    enabled: true
                )
                self.commit(binding: newBinding)
                return nil
            }
            return event
        }
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func commit(binding: HotkeyBinding) {
        self.binding = binding
        self.recording = false
        removeMonitor()
        onChange?(binding)
        window?.makeFirstResponder(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let radius: CGFloat = 6
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)

        if recording {
            NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
            path.fill()
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 1.4
            path.stroke()
        } else {
            NSColor.unemphasizedSelectedContentBackgroundColor.setFill()
            path.fill()
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        let label: NSString
        if recording {
            label = "Press keys…" as NSString
        } else if binding.enabled, binding.keyCode != 0 {
            let mods = HotkeyFormatting.modifierString(binding.modifiers)
            let key = HotkeyFormatting.keyString(binding.keyCode)
            label = (mods + key) as NSString
        } else {
            label = "Click to record" as NSString
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: recording
                ? NSColor.controlAccentColor
                : (binding.enabled ? NSColor.labelColor : NSColor.secondaryLabelColor),
        ]
        let textSize = label.size(withAttributes: attrs)
        let point = NSPoint(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2
        )
        label.draw(at: point, withAttributes: attrs)

        if binding.enabled, binding.keyCode != 0, !recording {
            let clearRect = NSRect(x: bounds.width - 18, y: bounds.midY - 6, width: 12, height: 12)
            let clearPath = NSBezierPath(ovalIn: clearRect)
            NSColor.secondaryLabelColor.withAlphaComponent(0.25).setFill()
            clearPath.fill()
            let x = "×" as NSString
            let xAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: NSColor.labelColor,
            ]
            let xSize = x.size(withAttributes: xAttrs)
            x.draw(at: NSPoint(x: clearRect.midX - xSize.width / 2, y: clearRect.midY - xSize.height / 2 + 0.5), withAttributes: xAttrs)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if binding.enabled, binding.keyCode != 0 {
            let clearRect = NSRect(x: bounds.width - 18, y: bounds.midY - 6, width: 12, height: 12).insetBy(dx: -2, dy: -2)
            let point = convert(event.locationInWindow, from: nil)
            if clearRect.contains(point) {
                commit(binding: .none)
            }
        }
    }
}
