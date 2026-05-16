import AppKit

/// Transparent NSView pinned over the menu bar status button that accepts URL
/// drops (from Safari, Chrome, Finder bookmark files, plain-text links, etc.)
/// and forwards them to a routing callback so the user can drop any link onto
/// the menu bar to send it through Junction.
final class StatusItemDropOverlay: NSView {
    private let onURL: (URL) -> Void

    init(onURL: @escaping (URL) -> Void) {
        self.onURL = onURL
        super.init(frame: .zero)
        wantsLayer = true
        registerForDraggedTypes([
            .URL,
            .fileURL,
            NSPasteboard.PasteboardType("public.url"),
            NSPasteboard.PasteboardType("public.file-url"),
            .string,
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // Drag events are dispatched to the registered drag destination
    // independently of mouse-event routing, but ordinary mouse events go to
    // whatever view sits on top. The NSStatusBarButton beneath us still needs
    // those clicks so the menu opens. Forward them up the responder chain to
    // the underlying button.
    override func mouseDown(with event: NSEvent) { forward(event) }
    override func rightMouseDown(with event: NSEvent) { forward(event) }
    override func otherMouseDown(with event: NSEvent) { forward(event) }
    override func mouseUp(with event: NSEvent) { forward(event) }
    override func rightMouseUp(with event: NSEvent) { forward(event) }
    override func otherMouseUp(with event: NSEvent) { forward(event) }

    private func forward(_ event: NSEvent) {
        guard let target = nextMouseEventTarget() else {
            super.mouseDown(with: event)
            return
        }
        switch event.type {
        case .leftMouseDown:  target.mouseDown(with: event)
        case .rightMouseDown: target.rightMouseDown(with: event)
        case .otherMouseDown: target.otherMouseDown(with: event)
        case .leftMouseUp:    target.mouseUp(with: event)
        case .rightMouseUp:   target.rightMouseUp(with: event)
        case .otherMouseUp:   target.otherMouseUp(with: event)
        default: break
        }
    }

    /// The closest ancestor that's a real responder for clicks — the
    /// `NSStatusBarButton` we're pinned over.
    private func nextMouseEventTarget() -> NSResponder? {
        var responder: NSResponder? = superview
        while let next = responder {
            if let button = next as? NSButton { return button }
            responder = next.nextResponder
        }
        return superview
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        urlFromDrag(sender) != nil ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        urlFromDrag(sender) != nil ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = urlFromDrag(sender) else { return false }
        onURL(url)
        return true
    }

    /// Pulls the first plausible http(s) URL from the drag pasteboard.
    /// Sources we accept, in priority order:
    ///   1. NSURL (Safari/Chrome's "drag this link" pasteboard).
    ///   2. file:// URLs ending in `.webloc` / `.url` (Finder bookmark files).
    ///   3. Plain-text strings that parse as a URL (Notes, terminals, etc.).
    private func urlFromDrag(_ sender: NSDraggingInfo) -> URL? {
        let pb = sender.draggingPasteboard
        let urls = (pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]) ?? []
        let raw = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.extractURL(
            from: urls,
            text: raw,
            bookmarkResolver: { Self.bookmarkContents(at: $0) }
        )
    }

    /// Pure helper used by ``urlFromDrag(_:)``; isolated for unit testing so we
    /// don't have to fake an `NSDraggingInfo`. `bookmarkResolver` is injected
    /// to keep on-disk reads out of tests by default.
    static func extractURL(
        from urls: [URL],
        text: String?,
        bookmarkResolver: (URL) -> URL? = { _ in nil }
    ) -> URL? {
        for url in urls {
            if let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return url
            }
            if url.isFileURL, let bookmark = bookmarkResolver(url),
               let scheme = bookmark.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return bookmark
            }
        }

        if let raw = text, !raw.isEmpty {
            if let url = URL(string: raw),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return url
            }
            // No scheme but looks domain-y: assume https.
            if !raw.contains("://"), raw.contains("."), !raw.contains(" "),
               let recovered = URL(string: "https://" + raw),
               recovered.host?.contains(".") == true {
                return recovered
            }
        }

        return nil
    }

    /// Reads `.webloc` (XML plist with a `URL` key) or `.url` (INI-style) bookmark files.
    static func bookmarkContents(at url: URL) -> URL? {
        let ext = url.pathExtension.lowercased()
        if ext == "webloc" {
            guard let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let raw = plist["URL"] as? String,
                  let bookmarked = URL(string: raw)
            else { return nil }
            return bookmarked
        }
        if ext == "url" {
            guard let text = try? String(contentsOf: url) else { return nil }
            for line in text.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.lowercased().hasPrefix("url=") {
                    return URL(string: String(trimmed.dropFirst(4)))
                }
            }
        }
        return nil
    }
}
