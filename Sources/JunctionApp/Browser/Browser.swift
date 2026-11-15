import AppKit

struct Browser: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let url: URL

    var id: String { bundleID }

    private static let icons = NSCache<NSString, NSImage>()

    var icon: NSImage {
        if let hit = Self.icons.object(forKey: url.path as NSString) { return hit }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        Self.icons.setObject(image, forKey: url.path as NSString)
        return image
    }
}
