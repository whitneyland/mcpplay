
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

    var body: some View {
        VStack {
            Text("About RiffMCP")
                .font(.title)
                .padding()
            ScrollView {
                Markdown(credits)
                    .padding()
            }
            Button("Close") {
                NSApplication.shared.keyWindow?.close()
            }
            .padding()
        }
        .onAppear(perform: loadCredits)
        .frame(minWidth: 400, minHeight: 400)
    }

    private func loadCredits() {
        if let url = Bundle.main.url(forResource: "CREDITS", withExtension: "md") {
            do {
                credits = try String(contentsOf: url)
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
