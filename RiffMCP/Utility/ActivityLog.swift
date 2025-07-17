
import Foundation
import SwiftUI

// Data model for a single event
struct ActivityEvent: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: EventType
    let transport: TransportType
    let requestData: String?
    let sequenceData: String?
    let responseData: String?
    
    enum TransportType: String, CaseIterable {
        case http = "HTTP"
        case stdio = "STDIO"
        
        var icon: String {
            switch self {
            case .http: return "network"
            case .stdio: return "terminal"
            }
        }
        
        var color: Color {
            switch self {
            case .http: return .blue
            case .stdio: return .green
            }
        }
    }

    enum EventType: String {
        case request = "network.arrow.down.left"
        case generation = "music.quarternote.3"
        case success = "checkmark.circle.fill"
        case error = "xmark.circle.fill"
        case notification = "bell.fill"
        case toolsList = "list.bullet"
        case toolsCall = "wrench.and.screwdriver.fill"
        case resourcesList = "folder.fill"
        case promptsList = "text.bubble.fill"

        var color: Color {
            switch self {
            case .request: return .blue
            case .generation: return .purple
            case .success: return .green
            case .error: return .red
            case .notification: return .orange
            case .toolsList: return .cyan
            case .toolsCall: return .indigo
            case .resourcesList: return .brown
            case .promptsList: return .pink
            }
        }
    }

    // Formatter for displaying the timestamp
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var timestampString: String {
        Self.formatter.string(from: timestamp)
    }
}

// View Model (ObservableObject) to manage and share the events
@MainActor
class ActivityLog: ObservableObject {
    @Published private(set) var events: [ActivityEvent] = []
    @Published private(set) var requestCount: Int = 0
    @Published private(set) var serverStatus: String = "Offline"
    @Published private(set) var statusColor: Color = .gray

    // Singleton pattern to make it easily accessible
    static let shared = ActivityLog()

    private init() {} // Private initializer for singleton

    func add(message: String, type: ActivityEvent.EventType, transport: ActivityEvent.TransportType, requestData: String? = nil, sequenceData: String? = nil, responseData: String? = nil) {
        // Prepend new events to the top of the list
        events.insert(ActivityEvent(timestamp: Date(), message: message, type: type, transport: transport, requestData: requestData, sequenceData: sequenceData, responseData: responseData), at: 0)

        // Keep the list from growing indefinitely
        if events.count > 100 {
            events.removeLast()
        }

        // Update metrics
        if type == .request {
            requestCount += 1
        }
    }
    
    func updateLastEventWithResponse(_ responseData: String) {
        guard !events.isEmpty else { return }
        let lastEvent = events[0]
        events[0] = ActivityEvent(
            timestamp: lastEvent.timestamp,
            message: lastEvent.message,
            type: lastEvent.type,
            transport: lastEvent.transport,
            requestData: lastEvent.requestData,
            sequenceData: lastEvent.sequenceData,
            responseData: responseData
        )
    }
    
    func clearLog() {
        events.removeAll()
        requestCount = 0
    }
    
    func copyPostEventsToClipboard() {
        let postEvents = events.filter { event in
            event.message.contains("POST /")
        }
        
        let logText = postEvents.map { event in
            var text = "[\(event.timestampString)] \(event.message)\n"
            
            if let requestData = event.requestData {
                text += "Request:\n\(requestData)\n"
            }
            
            if let responseData = event.responseData {
                text += "Response:\n\(responseData)\n"
            }
            
            return text
        }.joined(separator: "\n---\n\n")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logText, forType: .string)
    }

    func updateServerStatus(online: Bool, busy: Bool = false) {
        if online {
            if busy {
                self.serverStatus = "Busy"
                self.statusColor = .yellow
            } else {
                self.serverStatus = "Online"
                self.statusColor = .green
            }
        } else {
            self.serverStatus = "Offline"
            self.statusColor = .red
            self.requestCount = 0 // Reset on server stop
        }
    }
}
