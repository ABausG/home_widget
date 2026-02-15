// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "home_widget",
  platforms: [
    .iOS("14.0")
  ],
  products: [
    .library(name: "home-widget", targets: ["home_widget"])
  ],
  dependencies: [],
  targets: [
    .target(
      name: "home_widget",
      dependencies: []
    )
  ]
)
