// swift-tools-version: 5.5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AmmerSmartCards",
  platforms: [
    .iOS(.v13)
  ],
  products: [
    .library(
      name: "AmmerSmartCards",
      targets: ["AmmerSmartCards"]),
  ],
  dependencies: [
      
  ],
  targets: [
    .target(
      name: "AmmerSmartCards",
      dependencies: [],
      path: "Sources"),
    .testTarget(
      name: "AmmerSmartCardsTests",
      dependencies: ["AmmerSmartCards"]),
  ]
)
