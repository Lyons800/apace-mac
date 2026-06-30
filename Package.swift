// swift-tools-version: 6.2
import PackageDescription

// ApaceKit — the application's logic, kept out of the app shell so it can be built
// and tested in isolation. It starts with the domain core and grows outward into
// layered modules as features land.
//
//   ApaceCore  pure domain: the dictation state machine and value types.
//              No framework imports — fully unit-testable without hardware.
let package = Package(
    name: "ApaceKit",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ApaceCore"),
        .testTarget(name: "ApaceCoreTests", dependencies: ["ApaceCore"]),
    ]
)
