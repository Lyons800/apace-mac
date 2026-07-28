import ApaceClients
import AppKit
import ApplicationServices

extension FocusClient {
    /// Reads the focused UI element via Accessibility: the frontmost app's name and,
    /// when the element exposes them, its text value and selection. Returns nil only
    /// when nothing at all is readable (no permission, or no focused element) — the
    /// router copes with partial context.
    public static let live = FocusClient {
        let system = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                system, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
            let focusedRef, CFGetTypeID(focusedRef) == AXUIElementGetTypeID()
        else { return nil }
        let element = unsafeDowncast(focusedRef as AnyObject, to: AXUIElement.self)

        func string(_ attribute: String) -> String? {
            var value: CFTypeRef?
            guard
                AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
                let text = value as? String, !text.isEmpty
            else { return nil }
            // Cap so a huge document can't blow up the router prompt.
            return String(text.prefix(4000))
        }

        var pid: pid_t = 0
        let appName: String? =
            AXUIElementGetPid(element, &pid) == .success
            ? NSRunningApplication(processIdentifier: pid)?.localizedName : nil

        return FocusedField(
            appName: appName,
            selectedText: string(kAXSelectedTextAttribute),
            text: string(kAXValueAttribute)
        )
    }
}
