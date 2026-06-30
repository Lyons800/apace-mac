import SwiftUI

/// Apace's visual language in one place — the brand "signal" accent used across the
/// notch overlay, and shared surface/spacing tokens — so the overlay, settings, and
/// onboarding stay visually consistent as they're built out.
public enum Theme {
    /// The warm accent that drives the waveform and active states.
    public static let signal = Color(red: 1.0, green: 0.48, blue: 0.16)

    /// The opaque canvas behind notch content (also used to fill the floating
    /// fallback on non-notched displays so it never shows a grey material).
    public static let surface = Color.black

    public enum Spacing {
        public static let tight: CGFloat = 8
        public static let regular: CGFloat = 12
        public static let loose: CGFloat = 16
    }
}
