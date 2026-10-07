// swift-tools-version: 6.1
import Foundation
import PackageDescription

// Modular monolith: every module is its own target, so the compiler enforces boundaries.
//
// Open source core (MIT), builds and runs on its own:
//
//   Welp (executable: WhatsApp)
//     └── WelpApp (app, AppKit + SwiftUI; defines the WelpEdition extension point)
//           ├── Preferences ─────────────────────────────────┐
//           ├── GuardedChats ────────────────────────────────┤
//           ├── WhatsAppAccessibility ──▶ SendGuard ─────────┼──▶ SharedKernel
//           │                         └─▶ AccessibilitySupport
//           └── InputInterception (standalone)
//
// Welp Pro, in ee/ (Welp Commercial License), plugs into the core and never the reverse:
//
//   WelpPro (executable: the official app)
//     └── WelpProEdition ──▶ WelpApp, Licensing, SlackAccessibility (──▶ SendGuard, …)
//
// Without ee/, or with WELP_FOSS_ONLY=1, only the core is built.
let includesPro =
  ProcessInfo.processInfo.environment["WELP_FOSS_ONLY"] == nil
  && FileManager.default.fileExists(atPath: Context.packageDirectory + "/ee/Sources")

var products: [Product] = [.executable(name: "Welp", targets: ["Welp"])]
var dependencies: [Package.Dependency] = []

var targets: [Target] = [
  .target(name: "SharedKernel"),
  .target(name: "GuardedChats", dependencies: ["SharedKernel"]),
  .target(name: "SendGuard", dependencies: ["SharedKernel"]),
  .target(name: "Preferences", dependencies: ["SharedKernel"]),
  .target(name: "AccessibilitySupport"),
  .target(
    name: "WhatsAppAccessibility",
    dependencies: ["SharedKernel", "SendGuard", "AccessibilitySupport"]
  ),
  .target(name: "InputInterception"),
  .target(
    name: "WelpApp",
    dependencies: [
      "SharedKernel", "GuardedChats", "SendGuard", "Preferences", "WhatsAppAccessibility",
      "InputInterception",
    ],
    // Xcode compiles the String Catalog itself; `swift build` only copies it, so the
    // StringCatalogCompiler plugin compiles it for command-line builds.
    resources: [
      .process("Resources/Localizable.xcstrings"), .copy("Resources/MenuBarIcon.svg"),
      .copy("Resources/Glyphs"),
    ],
    plugins: ["StringCatalogCompiler"]
  ),
  .executableTarget(name: "Welp", dependencies: ["WelpApp"]),
  .plugin(name: "StringCatalogCompiler", capability: .buildTool()),
  .testTarget(name: "SharedKernelTests", dependencies: ["SharedKernel"]),
  .testTarget(name: "GuardedChatsTests", dependencies: ["GuardedChats"]),
  .testTarget(name: "SendGuardTests", dependencies: ["SendGuard"]),
  .testTarget(name: "AccessibilitySupportTests", dependencies: ["AccessibilitySupport"]),
  .testTarget(name: "PreferencesTests", dependencies: ["Preferences"]),
  .testTarget(name: "WelpAppTests", dependencies: ["WelpApp"]),
]

if includesPro {
  products.append(.executable(name: "WelpPro", targets: ["WelpPro"]))
  // Updates for the official app. The core has no third-party dependencies.
  dependencies.append(.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"))
  targets += [
    .target(
      name: "SlackAccessibility",
      dependencies: ["SharedKernel", "SendGuard", "AccessibilitySupport"],
      path: "ee/Sources/SlackAccessibility"
    ),
    .target(name: "Licensing", path: "ee/Sources/Licensing"),
    .target(
      name: "WelpProEdition",
      dependencies: [
        "WelpApp", "SharedKernel", "Licensing", "SlackAccessibility",
        .product(name: "Sparkle", package: "Sparkle"),
      ],
      path: "ee/Sources/WelpProEdition",
      resources: [.process("Resources/Localizable.xcstrings")],
      plugins: ["StringCatalogCompiler"]
    ),
    .executableTarget(
      name: "WelpPro", dependencies: ["WelpProEdition"], path: "ee/Sources/WelpPro",
      // build-app.sh embeds Sparkle.framework in Welp.app/Contents/Frameworks.
      linkerSettings: [
        .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
      ]),
    .testTarget(
      name: "SlackAccessibilityTests", dependencies: ["SlackAccessibility"],
      path: "ee/Tests/SlackAccessibilityTests"),
    .testTarget(
      name: "LicensingTests", dependencies: ["Licensing"], path: "ee/Tests/LicensingTests"),
    .testTarget(
      name: "WelpProEditionTests", dependencies: ["WelpProEdition"],
      path: "ee/Tests/WelpProEditionTests"),
  ]
}

let package = Package(
  name: "Welp",
  // Source language of the String Catalogs; also the fallback for unsupported languages.
  defaultLocalization: "en",
  platforms: [.macOS(.v14)],
  products: products,
  dependencies: dependencies,
  targets: targets
)
