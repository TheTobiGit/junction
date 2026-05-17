import Foundation

/// Overlay applied on top of the built-in tracker strip list.
///
/// - `additions`: extra param names to strip. An entry ending in `_` is treated
///   as a prefix (e.g. `"mc_"` strips `mc_eid`, `mc_cid`, etc.). All other
///   entries are matched as exact param names (case-insensitive).
/// - `disabled`: built-in param names or prefixes to suppress. Each entry is
///   matched exactly against the built-in `defaultExactParams` set or the
///   `defaultPrefixes` array (e.g. `"utm_"` suppresses the `utm_` prefix rule;
///   `"fbclid"` suppresses that exact param).
struct TrackerOverrides: Codable, Equatable {
    var additions: [String] = []
    var disabled: [String] = []
}
