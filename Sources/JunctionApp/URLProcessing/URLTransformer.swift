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
        transformers.reduce(url) { current, transformer in
            transformer.transform(current)
        }
    }

    func runTraced(_ url: URL) -> URLTransformResult {
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
    static var `default`: URLTransformPipeline {
        let settings = SettingsStore.shared.settings
        return URLTransformPipeline(transformers: [
            OutgoingRedirectUnwrapper(),
            RedirectTransformer(redirects: settings.redirects),
            AMPCollapser(),
            TrackerStripper(overrides: settings.trackerOverrides)
        ])
    }

    static func pipeline(globalOverrides: TrackerOverrides, ruleOverrides: TrackerOverrides?) -> URLTransformPipeline {
        let settings = SettingsStore.shared.settings
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
