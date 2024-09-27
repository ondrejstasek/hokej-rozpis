// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HockeyScheduleCalendar",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/dehesa/CodableCSV.git", from: "0.6.7"),
        .package(url: "https://github.com/swift-calendar/icalendarkit.git", from: "1.0.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "HockeyScheduleCalendar",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "CodableCSV", package: "CodableCSV"),
                .product(name: "ICalendarKit", package: "icalendarkit"),
            ]
        ),
    ]
)
