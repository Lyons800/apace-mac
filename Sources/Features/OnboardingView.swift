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
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.tight) {
            Text("Welcome to Apace")
                .font(.largeTitle.bold())
            Text("Dictate anywhere on your Mac. Grant a few permissions to get started.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func act(on permission: Permission) {
        switch permissions.status(permission) {
        case .notDetermined:
            Task { await permissions.request(permission) }
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
    let act: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.regular) {
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title).font(.headline)
                Text(permission.rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            Button("Grant", action: act)
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
