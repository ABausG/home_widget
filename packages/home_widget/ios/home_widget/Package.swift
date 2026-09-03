// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let flutterFrameworkPath = ProcessInfo.processInfo.environment[
  "FLUTTER_FRAMEWORK_SWIFT_PACKAGE_PATH"
] ?? "../FlutterFramework"

let package = Package(
  name: "home_widget",
  platforms: [
    .iOS("14.0")
  ],
  products: [
    .library(name: "home-widget", targets: ["home_widget"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: flutterFrameworkPath)
  ],
  targets: [
    .target(
      name: "home_widget",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ]
    )
  ]
)
