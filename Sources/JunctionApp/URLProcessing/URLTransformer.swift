import Foundation

protocol URLTransformer {
    var identifier: String { get }
    func transform(_ url: URL) -> URL
}

/// Result of running the pipeline along with a per-stage trace, so callers
/// (the picker) can show exactly which transformers fired and what they
/// changed.
struct URLTransformResult {
    struct Step: Hashable {
        let identifier: String
        let before: URL
        let after: URL
    }
    let original: URL
    let final: URL
    let steps: [Step]

    var didChange: Bool { original.absoluteString != final.absoluteString }
}

struct URLTransformPipeline {
    var transformers: [URLTransformer]

    func run(_ url: URL) -> URL {
        if url.scheme?.lowercased() == "file" { return url }
        return transformers.reduce(url) { current, transformer in
            transformer.transform(current)
        }
    }

    func runTraced(_ url: URL) -> URLTransformResult {
        if url.scheme?.lowercased() == "file" {
            return URLTransformResult(original: url, final: url, steps: [])
        }
        var current = url
        var steps: [URLTransformResult.Step] = []
        for transformer in transformers {
            let next = transformer.transform(current)
            if next.absoluteString != current.absoluteString {
                steps.append(.init(identifier: transformer.identifier, before: current, after: next))
            }
            current = next
        }
        return URLTransformResult(original: url, final: current, steps: steps)
    }
}

enum URLTransformers {
    internal static var settingsProvider: () -> JunctionSettings = { SettingsStore.shared.settings }

    static var `default`: URLTransformPipeline {
        let settings = settingsProvider()
        return URLTransformPipeline(transformers: [
            OutgoingRedirectUnwrapper(),
            RedirectTransformer(redirects: settings.redirects),
            AMPCollapser(),
            TrackerStripper(overrides: settings.trackerOverrides)
        ])
    }

    /// URL after redirect/AMP normalization but **before** global tracker stripping.
    /// Rule matching must use this so `queryContains` and per-rule `trackerOverrides`
    /// are evaluated against the original query string.
    static func urlForRuleMatching(_ url: URL) -> URL {
        let settings = settingsProvider()
        return URLTransformPipeline(transformers: [
            OutgoingRedirectUnwrapper(),
            RedirectTransformer(redirects: settings.redirects),
            AMPCollapser(),
        ]).run(url)
    }

    static func pipeline(globalOverrides: TrackerOverrides, ruleOverrides: TrackerOverrides?) -> URLTransformPipeline {
        let settings = settingsProvider()
        let trackerStripper: TrackerStripper
        if let ruleOverrides {
            let merged = TrackerOverrides(
                additions: globalOverrides.additions + ruleOverrides.additions,
                disabled: globalOverrides.disabled + ruleOverrides.disabled
            )
            trackerStripper = TrackerStripper(overrides: merged, identifier: "rule-tracker-stripper")
        } else {
            trackerStripper = TrackerStripper(overrides: globalOverrides)
        }
        return URLTransformPipeline(transformers: [
            OutgoingRedirectUnwrapper(),
            RedirectTransformer(redirects: settings.redirects),
            AMPCollapser(),
            trackerStripper
        ])
    }
}
