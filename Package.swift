// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "shape-tree",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "shape-tree", targets: ["ShapeTree"])
  ],
  dependencies: [
    .package(url: "https://github.com/zaneenders/scribe.git", revision: "0718ddb"),
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
  ],
  targets: [
    .executableTarget(
      name: "ShapeTree",
      dependencies: [
        .product(name: "ScribeCore", package: "scribe"),
        .product(name: "ScribeLLM", package: "scribe"),
        .product(name: "Hummingbird", package: "hummingbird"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ]
    ),
    .testTarget(
      name: "ShapeTreeTests",
      dependencies: [
        "ShapeTree",
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdTesting", package: "hummingbird"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ]
    ),
  ]
)
