//
//  ServerActivityView.swift
//  RiffMCP
//
//  Display server log info
//

import SwiftUI

struct ServerActivityView: View {
    @StateObject private var activityLog = ActivityLog.shared
    @State private var selectedEvent: ActivityEvent?
    @State private var showInspector: Bool = false

    var body: some View {
        if showInspector {
            HSplitView {
                // Main list view
                mainListView
                    .frame(minWidth: 300, idealWidth: 350, maxWidth: .infinity)
                
                // Inspector pane
                if let selectedEvent = selectedEvent {
                    EventInspectorView(event: selectedEvent)
                        .frame(minWidth: 200, idealWidth: 200, maxWidth: 600)
                } else {
                    VStack {
                        Image(systemName: "sidebar.right")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Select an event to view details")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 200, idealWidth: 200, maxWidth: 400)
                }
            }
        } else {
            mainListView
        }
    }
    
    private var mainListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with controls
            HStack {
                headerView
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    Button(action: {
                        activityLog.clearLog()
                        selectedEvent = nil
                        Log.app.info("Activity log cleared")
                    }) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Clear all log entries")
                    
                    Button(action: {
                        activityLog.copyPostEventsToClipboard()
                    }) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Copy POST events to clipboard")
                    
                    Button(action: { 
                        showInspector.toggle()
                        // If turning on inspector and no event selected, select the first one
                        if showInspector && selectedEvent == nil && !activityLog.events.isEmpty {
                            selectedEvent = activityLog.events.first
                        }
                    }) {
                        Image(systemName: showInspector ? "sidebar.right" : "sidebar.left")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Toggle Inspector")
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 5)

            Divider()

            // Metrics
            metricsView
                .padding(.horizontal)
                .padding(.vertical, 10)

            Divider()

            // Live Activity Feed
            activityFeedView
        }
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
        .clipped()
    }

    private var headerView: some View {
        Text("MCP Server Activity")
            .font(.headline)
            .foregroundColor(.white)
    }

    private var metricsView: some View {
        HStack(spacing: 20) {
            // Server Status
            HStack {
                Circle()
                    .fill(activityLog.statusColor)
                    .frame(width: 10, height: 10)
                Text(activityLog.serverStatus)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }

            // Request Count
            HStack {
                Text("Requests:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("\(activityLog.requestCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
    }

    private var activityFeedView: some View {
        List(activityLog.events, selection: $selectedEvent) { event in
            HStack(spacing: 12) {
                Image(systemName: event.type.rawValue)
                    .foregroundColor(event.type.color)
                    .font(.callout)
                    .frame(width: 20)

                Text(event.timestampString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)

                // Transport pill
                Label(event.transport.rawValue, systemImage: event.transport.icon)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .foregroundColor(event.transport.color)
                    .background(event.transport.color.opacity(0.15))
                    .clipShape(Capsule())

                Text(event.message)
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .listRowBackground(Color.clear)
            .padding(.vertical, 2)
            .tag(event)
        }
        .listStyle(PlainListStyle())
        .background(Color.clear)
    }
}

struct EventInspectorView: View {
    let event: ActivityEvent
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with event type and timestamp
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: event.type.rawValue)
                        .foregroundColor(event.type.color)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(eventTypeDisplayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(event.timestampString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
            }
            
            // Message
            VStack(alignment: .leading, spacing: 4) {
                Text("Message")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(event.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            
            // Data display based on event type
            if event.type == .generation, let sequenceData = event.sequenceData, !sequenceData.isEmpty {
                // Show clean sequence JSON for generation events
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Music Sequence")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button("Load in Editor") {
                            audioManager.receivedJSON = sequenceData
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    ScrollView {
                        Text(formatJSON(sequenceData))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
                }
            } else if let requestData = event.requestData, !requestData.isEmpty {
                // Show JSON-RPC request for other events
                VStack(alignment: .leading, spacing: 4) {
                    Text("Request")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ScrollView {
                        Text(formatJSON(requestData))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
                }
            }
            
            // Response Data (if available)
            if let responseData = event.responseData, !responseData.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Response")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ScrollView {
                        Text(formatJSON(responseData))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var eventTypeDisplayName: String {
        switch event.type {
        case .request: return "Request"
        case .generation: return "Generation"
        case .success: return "Success"
        case .error: return "Error"
        case .notification: return "Notification"
        case .toolsList: return "Tools List"
        case .toolsCall: return "Tool Call"
        case .resourcesList: return "Resources List"
        case .promptsList: return "Prompts List"
        }
    }
    
    private func formatJSON(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return jsonString
        }
        return prettyString
    }
}

struct ServerActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ServerActivityView()
            .onAppear {
                // Add some dummy data for previewing
                let log = ActivityLog.shared
                log.updateServerStatus(online: true)
                log.add(message: "New request: play a C major scale", type: .request, transport: .http, requestData: """
                {
                  "jsonrpc": "2.0",
                  "id": 1,
                  "method": "tools/call",
                  "params": {
                    "name": "play",
                    "arguments": {
                      "tempo": 120,
                      "tracks": [
                        {
                          "instrument": "grand_piano",
                          "events": []
                        }
                      ]
                    }
                  }
                }
                """)
                log.add(message: "Generated 12 notes for Piano", type: .generation, transport: .http)
                log.add(message: "Playback complete", type: .success, transport: .stdio)
                log.add(message: "Invalid instrument: 'banjo'", type: .error, transport: .http)
            }
            .frame(width: 800, height: 500)
            .background(Color.gray.opacity(0.3))
    }
}
