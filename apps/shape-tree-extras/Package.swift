// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "shape-tree-extras",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .library(name: "ShapeTreeEmail", targets: ["ShapeTreeEmail"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.100.0"),
    .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.34.0"),
    .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.31.0"),
    .package(url: "https://github.com/apple/swift-nio-imap.git", from: "0.1.0"),
    .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "ShapeTreeEmail",
      dependencies: [
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
        .product(name: "NIOExtras", package: "swift-nio-extras"),
        .product(name: "NIOFoundationCompat", package: "swift-nio"),
        .product(name: "NIOIMAP", package: "swift-nio-imap"),
        .product(name: "NIOSSL", package: "swift-nio-ssl"),
        .product(name: "Configuration", package: "swift-configuration"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
      ]
    ),
    .testTarget(
      name: "ShapeTreeEmailTests",
      dependencies: ["ShapeTreeEmail"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
      ]
    ),
  ]
)
