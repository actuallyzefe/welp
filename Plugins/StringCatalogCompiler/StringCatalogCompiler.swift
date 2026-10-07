import Foundation
import PackagePlugin

/// Compiles a target's String Catalogs (`.xcstrings`) into `<language>.lproj` resources.
///
/// Xcode does this natively, but `swift build` only copies catalogs verbatim, so translations
/// would never load in command-line builds (the Makefile, CI, `build-app.sh`). Declare the
/// catalog as a `.process` resource as well, for Xcode; Xcode does not run this plugin's
/// commands for packages, so the two never produce the same files.
@main
struct StringCatalogCompiler: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    guard let target = target as? SourceModuleTarget else { return [] }
    let xcrun = URL(filePath: "/usr/bin/xcrun")
    let outputDirectory = context.pluginWorkDirectoryURL.appending(path: "Localizations")

    return try catalogs(in: target.directoryURL).map { catalog in
      let arguments = [
        "xcstringstool", "compile", catalog.path(), "--output-directory", outputDirectory.path(),
      ]
      // Declaring the exact outputs is what makes SwiftPM bundle them as localized resources.
      // The compiler itself knows which files a catalog produces.
      let outputs = try run(xcrun, arguments + ["--dry-run"])
        .split(separator: "\n")
        .map { URL(filePath: String($0)) }
      return .buildCommand(
        displayName: "Compiling \(catalog.lastPathComponent)",
        executable: xcrun,
        arguments: arguments,
        inputFiles: [catalog],
        outputFiles: outputs
      )
    }
  }

  private func catalogs(in directory: URL) -> [URL] {
    let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
    return (files?.allObjects as? [URL] ?? [])
      .filter { $0.pathExtension == "xcstrings" }
      .sorted { $0.path() < $1.path() }
  }

  private func run(_ executable: URL, _ arguments: [String]) throws -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = executable
    process.arguments = arguments
    process.standardOutput = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw PluginError.toolFailed(arguments.joined(separator: " "))
    }
    return String(decoding: data, as: UTF8.self)
  }
}

enum PluginError: Error, CustomStringConvertible {
  case toolFailed(String)

  var description: String {
    switch self {
    case .toolFailed(let command): "xcrun \(command) failed"
    }
  }
}
