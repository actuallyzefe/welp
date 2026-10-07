/// A supported messaging app.
public enum Messenger: String, Codable, Sendable, CaseIterable {
  case whatsApp = "whatsapp"
  case slack

  public var displayName: String {
    switch self {
    case .whatsApp: "WhatsApp"
    case .slack: "Slack"
    }
  }
}
