// swift-tools-version: 6.3

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .swiftLanguageMode(.v6),
  .treatAllWarnings(as: .error),
]

let package = Package(
  name: "raft-workflow-node",
  products: [
    .executable(name: "raft-workflow-node", targets: ["raft-workflow-node"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.99.0"),
    .package(url: "https://github.com/apple/swift-system.git", from: "1.4.0"),
    .package(url: "https://github.com/zaneenders/swift-raft.git", revision: "841decd"),
  ],
  targets: [
    .target(
      name: "Workflow",
      dependencies: [
        .product(name: "SystemPackage", package: "swift-system"),
        .product(name: "_NIOFileSystem", package: "swift-nio"),
        .product(name: "Logging", package: "swift-log"),
      ],
      swiftSettings: swiftSettings
    ),
    .target(
      name: "RaftWorkflow",
      dependencies: [
        "Workflow",
        .product(name: "Raft", package: "swift-raft"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
      ],
      swiftSettings: swiftSettings
    ),
    .executableTarget(
      name: "raft-workflow-node",
      dependencies: [
        "RaftWorkflow",
        .product(name: "Raft", package: "swift-raft"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
      ],
      swiftSettings: swiftSettings
    ),
  ]
)
