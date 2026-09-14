import Foundation
import SwiftUI

@Observable
final class SessionManager: @unchecked Sendable {
    static let shared = SessionManager()

    var token: String? {
        didSet {
            if let token = token {
                UserDefaults.standard.set(token, forKey: "cineclaw_session_token")
            } else {
                UserDefaults.standard.removeObject(forKey: "cineclaw_session_token")
            }
        }
    }

    var username: String? {
        didSet {
            UserDefaults.standard.set(username, forKey: "cineclaw_username")
        }
    }

    var isPaired: Bool {
        token != nil && !(token?.isEmpty ?? true)
    }

    private init() {
        self.token = UserDefaults.standard.string(forKey: "cineclaw_session_token")
        self.username = UserDefaults.standard.string(forKey: "cineclaw_username")
    }

    func setSession(token: String, username: String?) {
        self.token = token
        self.username = username
        NotificationCenter.default.post(name: .serverOrSessionDidChange, object: nil)
    }

    func clearSession() {
        self.token = nil
        self.username = nil
        NotificationCenter.default.post(name: .serverOrSessionDidChange, object: nil)
    }
}

extension Notification.Name {
    static let serverOrSessionDidChange = Notification.Name("CineClawServerOrSessionDidChange")
}
