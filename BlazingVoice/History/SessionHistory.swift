import Foundation

final class SessionHistory: ObservableObject {
    enum SessionStatus: String {
        case pending, completed
    }

    struct Session: Identifiable {
        let id: UUID
        let rawText: String
        let soapText: String
        let date: Date
        var status: SessionStatus

        var timestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
    }

    @Published private(set) var sessions: [Session] = []

    private let maxSessions = 10

    @discardableResult
    func addSession(rawText: String, soapText: String) -> Session {
        let session = Session(
            id: UUID(),
            rawText: rawText,
            soapText: soapText,
            date: Date(),
            status: .pending
        )
        sessions.append(session)

        // Keep only the last N sessions
        if sessions.count > maxSessions {
            sessions.removeFirst(sessions.count - maxSessions)
        }

        return session
    }

    func updateStatus(id: UUID, status: SessionStatus) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].status = status
        }
    }

    func clearHistory() {
        sessions.removeAll()
    }
}
