
//
//  AboutView.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/27/25.
//

import SwiftUI
import MarkdownUI

struct AboutView: View {
    @State private var credits: String = ""
    
    private var appVersionText: String {
        return "\(AppInfo.name) v\(AppInfo.fullVersion)"
    }

    var body: some View {
        VStack {
            Text(appVersionText)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom)

            ScrollView {
                Markdown(credits)
                    .padding()
            }
            Button {
                NSApplication.shared.keyWindow?.close()
            } label: {
                Text("Close")
                    .frame(width: 100, height: 24)
            }
            .padding()
        }
        .onAppear(perform: loadCredits)
        .frame(minWidth: 400, minHeight: 400)
        .padding()
    }

    private func loadCredits() {
        if let url = Bundle.main.url(forResource: "CREDITS", withExtension: "md") {
            do {
                credits = try String(contentsOf: url, encoding: .utf8)
            } catch {
                credits = "Could not load credits file."
            }
        } else {
            credits = "Credits file not found."
        }
    }
}

#Preview {
    AboutView()
}
