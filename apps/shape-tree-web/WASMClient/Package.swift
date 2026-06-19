// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "WASMClient",
  platforms: [
    .macOS(.v13),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.37.0"),
  ],
  targets: [
    .executableTarget(
      name: "WASMClient",
      dependencies: [
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("Extern"),
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-Osize"], .when(configuration: .release)),
      ]
    ),
  ]
)
