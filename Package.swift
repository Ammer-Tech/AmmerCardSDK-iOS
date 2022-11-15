// swift-tools-version: 5.5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AmmerCardsSDK",
  platforms: [
    .iOS(.v13)
  ],
  products: [
    .library(
      name: "AmmerCardsSDK",
      targets: ["AmmerCardsSDK"]),
  ],
  dependencies: [
      
  ],
  targets: [
    .target(
      name: "AmmerCardsSDK",
      dependencies: [],
      path: "Sources"),
    .testTarget(
      name: "AmmerCardsSDKTests",
      dependencies: ["AmmerCardsSDK"]),
  ]
)
