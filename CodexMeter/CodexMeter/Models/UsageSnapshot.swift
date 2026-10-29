import Foundation

/// Usage windows and reset details returned by Codex app-server.
struct UsageSnapshot: Equatable, Sendable {
    /// The short session window, when published by Codex.
    let session: UsageWindow?

    /// The long weekly window, when published by Codex.
    let weekly: UsageWindow?

    /// Banked reset count and nearest expiry. `nil` when no reset is
    /// available or the supplementary endpoint could not provide details.
    let bankedResetInfo: BankedResetInfo?

    /// Windows this long or shorter are session windows; anything longer
    /// is the weekly bucket. 24h sits in the wide empty gap between the
    /// two families (5h vs 7d), so the split survives OpenAI retuning
    /// either window without us having to chase the exact value.
    static let sessionMaxDuration: TimeInterval = 24 * 3600

    init(
        session: UsageWindow?,
        weekly: UsageWindow?,
        bankedResetInfo: BankedResetInfo? = nil
    ) {
        self.session = session
        self.weekly = weekly
        self.bankedResetInfo = bankedResetInfo
    }

    subscript(window: TrackedWindow) -> UsageWindow? {
        switch window {
        case .session: return session
        case .weekly: return weekly
        }
    }

    /// The windows the API is currently publishing, in display order.
    var availableWindows: [TrackedWindow] {
        TrackedWindow.allCases.filter { self[$0] != nil }
    }

    /// The window the UI should actually show, honoring `preference` but
    /// falling back to the other one when the preferred window isn't
    /// published. Returns `nil` when the response carried no windows at
    /// all. Without this, a saved preference of `.session` would leave the
    /// menu bar blank for as long as OpenAI keeps session limits retired.
    func resolvedWindow(preferring preference: TrackedWindow) -> TrackedWindow? {
        if self[preference] != nil { return preference }
        if self[preference.other] != nil { return preference.other }
        return nil
    }

    /// Sorts the two positional API slots into session/weekly by the
    /// length each window reports.
    ///
    /// Slot position is not a reliable identifier: OpenAI moved the weekly
    /// window into `primary_window` (leaving `secondary_window` null) when
    /// they dropped session limits, which made a position-based parser
    /// label weekly usage as session usage. Length is stable — a 5h window
    /// says 18000 wherever it appears.
    ///
    /// Falls back to the historical positional mapping for any window that
    /// omits reported duration, which is the best guess available
    /// when the identifying field is missing.
    static func classify(
        primary: UsageWindow?,
        secondary: UsageWindow?
    ) -> (session: UsageWindow?, weekly: UsageWindow?) {
        var session: UsageWindow?
        var weekly: UsageWindow?

        // Windows that report their own length are placed by length. First
        // one into a slot wins; the API has never sent two of a kind.
        for window in [primary, secondary].compactMap({ $0 }) {
            guard let duration = window.duration else { continue }
            if duration <= sessionMaxDuration {
                if session == nil { session = window }
            } else if weekly == nil {
                weekly = window
            }
        }

        // Legacy fallback for windows with no reported duration, only
        // for slots nothing else claimed.
        if let primary, primary.duration == nil, session == nil { session = primary }
        if let secondary, secondary.duration == nil, weekly == nil { weekly = secondary }

        return (session, weekly)
    }

}
