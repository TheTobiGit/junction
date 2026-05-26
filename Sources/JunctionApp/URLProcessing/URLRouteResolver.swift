import Foundation

struct ResolvedRoute {
    let trace: URLTransformResult
    let match: RulesStore.RuleMatch
    let cleaningEnabled: Bool
    let urlToOpen: URL
}

/// Single source of truth for "match rule → build pipeline → resolve clean flag → pick final URL".
///
/// Replaces the duplicated block previously inlined in
/// ``AppDelegate.routeAfterExpansion``, ``AppDelegate.routeAgent``,
/// ``AppDelegate.handleJunctionScheme`` (junction://open path),
/// ``PickerPanelController`` openOnce, ``PickerViewModel.init``, and
/// ``ClipboardURLContext.analyze``.
///
/// Callers that need the app-scheme rewrite / scheme-allowlist preflight
/// (currently only ``AppDelegate.routeAfterExpansion``) keep that logic
/// inline before calling this; the resolver only owns the pipeline +
/// match + cleaning resolution.
enum URLRouteResolver {
    /// - Parameters:
    ///   - url: The URL whose route is being resolved. The pipeline runs against this
    ///     URL — for the post-expansion path that's the redirected URL, for the picker
    ///     mirrors and clipboard analysis that's the URL the user clicked/copied.
    ///   - context: Frontmost source + focus context, used by `when` rule conditions.
    ///   - explicitClean: When the caller has a pinned `clean=…` override (CLI, agent,
    ///     `junction://open?clean=…`), pass it here; it wins over both rule and global.
    ///   - precomputedGlobalTrace: Callers that already ran the default (global) pipeline
    ///     on `url` (currently ``AppDelegate.routeAfterExpansion`` does this for the
    ///     scheme/app-scheme preflight) can pass it here so the resolver doesn't redo
    ///     that work. Must be the result of `URLTransformers.default.runTraced(url)` —
    ///     anything else will mismatch the rule pipeline and cause subtle bugs.
    static func resolve(
        url: URL,
        context: RouteContext,
        explicitClean: Bool? = nil,
        precomputedGlobalTrace: URLTransformResult? = nil
    ) -> ResolvedRoute {
        let globalSettings = SettingsStore.shared.settings
        let match = RulesStore.shared.match(
            url: URLTransformers.urlForRuleMatching(url),
            context: context
        )

        // Match first so we know whether the rule needs a per-rule pipeline.
        // When overrides are present we run the merged pipeline once; when
        // they're absent we use the caller's precomputed global trace if any,
        // otherwise run the default pipeline once. Either way: one trace.
        let trace: URLTransformResult
        if let ruleOverrides = match.rule?.trackerOverrides {
            trace = URLTransformers.pipeline(
                globalOverrides: globalSettings.trackerOverrides,
                ruleOverrides: ruleOverrides
            ).runTraced(url)
        } else if let precomputedGlobalTrace {
            trace = precomputedGlobalTrace
        } else {
            trace = URLTransformers.default.runTraced(url)
        }

        let cleaningEnabled: Bool
        if let explicit = explicitClean {
            cleaningEnabled = explicit
        } else {
            cleaningEnabled = DomainRule.resolveCleanFlag(
                rule: match.rule,
                globalEnabled: globalSettings.cleanURLsBeforeOpening
            )
        }

        let urlToOpen = cleaningEnabled ? trace.final : url
        return ResolvedRoute(
            trace: trace,
            match: match,
            cleaningEnabled: cleaningEnabled,
            urlToOpen: urlToOpen
        )
    }
}
