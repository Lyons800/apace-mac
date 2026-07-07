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
        .library(
            name: "Adapters",
            targets: ["AudioCapture", "Transcription", "SystemServices", "TextCleanup", "Automation"]
        ),
        .library(name: "ApaceKit", targets: ["ApaceCore", "ApaceClients", "DictationPipeline"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    dependencies: [
        // On-device ASR engines. Pinned to the versions the previous app shipped so
        // the integration is against a known-good API surface.
        // WhisperKit 1.0 vendors its tokenizer and uses swift-transformers 1.2, which
        // co-resolves with the MLX cleanup model below (0.14.1 pinned an older one).
        .package(url: "https://github.com/argmaxinc/WhisperKit", exact: "1.0.0"),
        .package(url: "https://github.com/FluidInference/FluidAudio", exact: "0.15.4"),
        // On-device cleanup LLM for Macs without Apple Intelligence (a small local model
        // via MLX). 2.31.3 has the fixed manifest and pairs with WhisperKit 1.0.
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", exact: "3.31.4"),
    ],
    targets: [
        // MARK: Domain
        .target(name: "ApaceCore"),
        .target(name: "ApaceClients", dependencies: ["ApaceCore"]),

        // MARK: Application
        .target(name: "DictationPipeline", dependencies: ["ApaceCore", "ApaceClients"]),

        // MARK: Infrastructure (live adapters)
        .target(name: "AudioCapture", dependencies: ["ApaceClients"]),
        .target(
            name: "Transcription",
            dependencies: [
                "ApaceClients",
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
        .target(name: "SystemServices", dependencies: ["ApaceClients"]),
        .target(name: "Automation", dependencies: ["ApaceClients", "ApaceCore"]),
        .target(
            name: "TextCleanup",
            dependencies: [
                "ApaceClients",
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ]
        ),

        // MARK: UI
        .target(
            name: "DesignSystem",
            dependencies: ["ApaceCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "Features",
            dependencies: ["ApaceCore", "ApaceClients", "DictationPipeline", "DesignSystem"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),

        // MARK: Tests
        .testTarget(name: "ApaceCoreTests", dependencies: ["ApaceCore", "ApaceClients"]),
        .testTarget(
            name: "DictationPipelineTests",
            dependencies: ["DictationPipeline", "ApaceCore", "ApaceClients"]
        ),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["Features", "ApaceCore", "ApaceClients"]
        ),
        .testTarget(name: "TextCleanupTests", dependencies: ["TextCleanup"]),
        .testTarget(name: "AutomationTests", dependencies: ["Automation"]),
    ]
)
