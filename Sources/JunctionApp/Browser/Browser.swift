import AppKit

struct Browser: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let url: URL

    var id: String { bundleID }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}
