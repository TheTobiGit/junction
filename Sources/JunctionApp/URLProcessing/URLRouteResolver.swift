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
    static func resolve(
        url: URL,
        context: RouteContext,
        explicitClean: Bool? = nil
    ) -> ResolvedRoute {
        let globalSettings = SettingsStore.shared.settings
        let globalTrace = URLTransformers.default.runTraced(url)
        let match = RulesStore.shared.match(
            url: URLTransformers.urlForRuleMatching(url),
            context: context
        )

        let trace: URLTransformResult
        if let ruleOverrides = match.rule?.trackerOverrides {
            trace = URLTransformers.pipeline(
                globalOverrides: globalSettings.trackerOverrides,
                ruleOverrides: ruleOverrides
            ).runTraced(url)
        } else {
            trace = globalTrace
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
