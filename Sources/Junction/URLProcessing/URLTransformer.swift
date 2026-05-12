import Foundation

protocol URLTransformer {
    var identifier: String { get }
    func transform(_ url: URL) -> URL
}

struct URLTransformPipeline {
    var transformers: [URLTransformer]

    func run(_ url: URL) -> URL {
        transformers.reduce(url) { current, transformer in
            transformer.transform(current)
        }
    }
}

enum URLTransformers {
    static var `default`: URLTransformPipeline {
        URLTransformPipeline(transformers: [
            RedirectTransformer(redirects: SettingsStore.shared.settings.redirects),
            AMPCollapser(),
            TrackerStripper()
        ])
    }
}
