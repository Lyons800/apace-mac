import ApaceClients
import ApaceCore
import DesignSystem
import SwiftUI

/// First-run onboarding: walks the user through the permissions Apace needs, one card
/// each, and unlocks "Start dictating" once they're all granted. It re-reads status on
/// appear because the user may grant Accessibility over in System Settings.
public struct OnboardingView: View {
    private let permissions: PermissionsModel
    private let onDone: () -> Void

    public init(permissions: PermissionsModel, onDone: @escaping () -> Void) {
        self.permissions = permissions
        self.onDone = onDone
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.loose) {
            header

            VStack(spacing: Theme.Spacing.tight) {
                ForEach(Permission.allCases, id: \.self) { permission in
                    PermissionRow(
                        permission: permission,
                        status: permissions.status(permission),
                        hasRequested: permissions.hasRequested(permission),
                        act: { act(on: permission) }
                    )
                }
            }

            Button(action: onDone) {
                Text("Start dictating").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(Theme.signal)
            .disabled(!permissions.allGranted)
        }
        .padding(Theme.Spacing.loose)
        .frame(width: 420)
        .onAppear { permissions.refresh() }
        .task {
            while !Task.isCancelled, !permissions.allGranted {
                try? await Task.sleep(for: .seconds(1))
                permissions.refresh()
            }
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.tight) {
            Text("Welcome to Apace")
                .font(.largeTitle.bold())
            Text(
                "Grant the permissions below, then hold Right Option to dictate and "
                    + "release to insert your text."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
    }

    private func act(on permission: Permission) {
        switch permissions.status(permission) {
        case .notDetermined:
            if permissions.hasRequested(permission) {
                permissions.openSettings(permission)
            } else {
                Task { await permissions.request(permission) }
            }
        case .denied:
            permissions.openSettings(permission)
        case .granted:
            break
        }
    }
}

/// One permission's card: title, why Apace needs it, and the right control for its
/// current state — grant it, open Settings if refused, or a check once it's given.
private struct PermissionRow: View {
    let permission: Permission
    let status: PermissionStatus
    let hasRequested: Bool
    let act: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.regular) {
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title).font(.headline)
                Text(permission.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if permission == .accessibility, hasRequested, status != .granted {
                    Text(
                        "Already enabled? Turn Apace off and on again, or remove the old "
                            + "entry and add this copy."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
            control
        }
        .padding(Theme.Spacing.regular)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var control: some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        case .notDetermined:
            Button(hasRequested ? "Open Settings" : "Grant", action: act)
        case .denied:
            Button("Open Settings", action: act)
        }
    }
}

#Preview {
    OnboardingView(
        permissions: PermissionsModel(
            client: PermissionsClient(
                status: { _ in .notDetermined },
                request: { _ in .granted },
                openSettings: { _ in }
            )
        ),
        onDone: {}
    )
}
