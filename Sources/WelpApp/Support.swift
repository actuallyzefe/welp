import AppKit
import SharedKernel
import os

enum AppPaths {
  static var guardedChatsFile: URL {
    URL.applicationSupportDirectory
      .appending(path: "Welp", directoryHint: .isDirectory)
      .appending(path: "guarded-chats.json")
  }
}

/// `AppLogger` backed by the unified logging system (visible in Console.app).
struct OSLogLogger: AppLogger {
  private let logger: Logger

  init(category: String) {
    logger = Logger(subsystem: "dev.karakanli.welp", category: category)
  }

  func debug(_ message: String) { logger.debug("\(message, privacy: .public)") }
  func info(_ message: String) { logger.info("\(message, privacy: .public)") }
  func warning(_ message: String) { logger.warning("\(message, privacy: .public)") }
  func error(_ message: String) { logger.error("\(message, privacy: .public)") }
}

extension String {
  public static var settingNotSaved: String {
    String(
      localized: "Couldn’t save the setting", bundle: .localization, comment: "Error alert title.")
  }
}

@MainActor
public enum ErrorPresenter {
  public static func show(title: String, error: any Error) {
    present(title: title, message: error.localizedDescription, style: .critical)
  }

  private static func present(title: String, message: String, style: NSAlert.Style) {
    let alert = NSAlert()
    alert.alertStyle = style
    alert.messageText = title
    alert.informativeText = message
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
  }
}
