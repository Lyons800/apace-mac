// swift-tools-version: 6.2
import PackageDescription

// ApaceKit — the application's logic, split into layered modules so dependencies
// point strictly inward (Features → Core ← Infrastructure). The thin `.app`
// shell sits on top and wires the live adapters at its composition root.
//
//   ApaceCore        pure domain: the dictation state machine and value types.
//                    No framework imports — fully unit-testable without hardware.
//   ApaceClients     the "ports": struct-of-closures abstractions over every
//                    system service the domain needs (audio, transcription,
//                    hotkeys, text insertion, persistence).
//   AudioCapture  ┐  the "adapters": live implementations of the ports, each
//   Transcription ├─ wrapping a single Apple/3rd-party framework. Imported only
//   SystemServices┘  by the app shell, never by the domain.
//   DesignSystem     reusable UI (the notch overlay, components, theme).
//   Features         one `@Observable` store + SwiftUI view per surface.
let package = Package(
    name: "ApaceKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Features", targets: ["Features"]),
        .library(name: "Adapters", targets: ["AudioCapture", "Transcription", "SystemServices"]),
    ],
    targets: [
        // MARK: Domain
        .target(name: "ApaceCore"),
        .target(name: "ApaceClients", dependencies: ["ApaceCore"]),

        // MARK: Application
        .target(name: "DictationPipeline", dependencies: ["ApaceCore", "ApaceClients"]),

        // MARK: Infrastructure (live adapters)
        .target(name: "AudioCapture", dependencies: ["ApaceClients"]),
        .target(name: "Transcription", dependencies: ["ApaceClients"]),
        .target(name: "SystemServices", dependencies: ["ApaceClients"]),

        // MARK: UI
        .target(
            name: "DesignSystem",
            dependencies: ["ApaceCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "Features",
            dependencies: ["ApaceCore", "ApaceClients", "DesignSystem"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),

        // MARK: Tests
        .testTarget(name: "ApaceCoreTests", dependencies: ["ApaceCore", "ApaceClients"]),
        .testTarget(
            name: "DictationPipelineTests",
            dependencies: ["DictationPipeline", "ApaceCore", "ApaceClients"]
        ),
    ]
)
