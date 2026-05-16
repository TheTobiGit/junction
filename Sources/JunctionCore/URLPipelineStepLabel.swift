import Foundation

/// Single source of truth for the human-readable label of a URL pipeline
/// transformer identifier. The picker, URL inspector, clipboard HUD trace,
/// CLI `inspect`, and routing history summary all render the same string for
/// the same step, so this lives in `JunctionCore` to be importable from both
/// the app and the CLI without pulling in AppKit.
public enum URLPipelineStepLabel {
    public static func label(for identifier: String) -> String {
        switch identifier {
        case "outgoing-redirect-unwrapper": return "Unwrapped tracking redirect"
        case "domain-redirect":             return "Applied domain redirect"
        case "amp-collapser":               return "Collapsed AMP URL"
        case "tracker-stripper":            return "Removed tracking parameters"
        default:                            return identifier
        }
    }
}
