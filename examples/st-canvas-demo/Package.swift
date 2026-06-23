// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "STCanvasDemo",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.37.0"),
  ],
  targets: [
    .executableTarget(
      name: "Canvas",
      dependencies: [.product(name: "JavaScriptKit", package: "JavaScriptKit")],
      swiftSettings: [
        .enableExperimentalFeature("Extern"),
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-Osize"], .when(configuration: .release)),
      ]
    ),
  ]
)
