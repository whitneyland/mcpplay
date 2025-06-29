
import SwiftUI

struct ServerActivityView: View {
    @StateObject private var activityLog = ActivityLog.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView
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
        List(activityLog.events) { event in
            HStack(spacing: 12) {
                Image(systemName: event.type.rawValue)
                    .foregroundColor(event.type.color)
                    .font(.callout)
                    .frame(width: 20)

                Text(event.timestampString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)

                Text(event.message)
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .listRowBackground(Color.clear)
            .padding(.vertical, 2)
        }
        .listStyle(PlainListStyle())
        .background(Color.clear)
    }
}

struct ServerActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ServerActivityView()
            .onAppear {
                // Add some dummy data for previewing
                let log = ActivityLog.shared
                log.updateServerStatus(online: true)
                log.add(message: "New request: play a C major scale", type: .request)
                log.add(message: "Generated 12 notes for Piano", type: .generation)
                log.add(message: "Playback complete", type: .success)
                log.add(message: "Invalid instrument: 'banjo'", type: .error)
            }
            .frame(width: 400, height: 500)
            .background(Color.gray.opacity(0.3))
    }
}
