//
//  SVGToPNGRenderer.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/8/25.
//

import Foundation
import WebKit
import AppKit
import SwiftUI

// Headless SVG rendering that we can use to serve images without UI
struct SVGToPNGRenderer {

    // MARK: Public entry point
    @MainActor
    static func renderToPNG(svgString: String,
                            size: CGSize? = nil) async throws -> Data
    {
        let renderSize = Self.computeRenderSize(from: svgString,
                                                requestedOverride: size)

        // Off-screen WebKit snapshot
        let webView = WKWebView(frame: CGRect(origin: .zero, size: renderSize))

        return try await withCheckedThrowingContinuation { continuation in
            // Keep delegate alive for the snapshot life-cycle
            let coordinator = HeadlessCoordinator(
                svgString: svgString,
                renderSize: renderSize,
                continuation: continuation
            )

            webView.navigationDelegate = coordinator
            objc_setAssociatedObject(webView,
                                     "headlessCoordinator",
                                     coordinator,
                                     .OBJC_ASSOCIATION_RETAIN)

            webView.loadHTMLString(Self.htmlTemplate(for: svgString),
                                   baseURL: nil)
        }
    }

    // MARK: Convenience helpers
    static func intrinsicSize(of svgString: String) -> CGSize? {
        if let (w, h) = Self.extractDimensions(from: svgString) {
            return CGSize(width: w, height: h)
        }
        return nil
    }

    static func extractDimensions(from svg: String) -> (width: Int, height: Int)? {
        // NOTE: Still limited to explicit width/height attrs; viewBox parsing TBD.
        let pattern = #"width="(\d+)[a-zA-Z]*"\s+height="(\d+)[a-zA-Z]*""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: svg,
                                           range: NSRange(svg.startIndex..., in: svg)),
              let widthRange  = Range(match.range(at: 1), in: svg),
              let heightRange = Range(match.range(at: 2), in: svg),
              let width       = Int(svg[widthRange]),
              let height      = Int(svg[heightRange]) else {
            return nil
        }
        return (width, height)
    }

    // MARK: Private implementation
    private static let defaultPageSize = Constants.Verovio.defaultPageSize

    private static func computeRenderSize(from svg: String,
                                          requestedOverride: CGSize?) -> CGSize
    {
        requestedOverride
        ?? Self.intrinsicSize(of: svg)
        ?? defaultPageSize
    }

    private static func htmlTemplate(for svg: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { background: white; width: fit-content; height: fit-content; }
                svg  { display: block; }
            </style>
        </head>
        <body>
        \(svg)
        </body>
        </html>
        """
    }

    // MARK: Headless snapshot delegate
    private class HeadlessCoordinator: NSObject, WKNavigationDelegate {
        let svgString: String
        let renderSize: CGSize
        var continuation: CheckedContinuation<Data, Error>?

        init(svgString: String,
             renderSize: CGSize,
             continuation: CheckedContinuation<Data, Error>)
        {
            self.svgString    = svgString
            self.renderSize   = renderSize
            self.continuation = continuation
        }

        func webView(_ webView: WKWebView,
                     didFinish navigation: WKNavigation!)
        {
            let config = WKSnapshotConfiguration()
            config.rect = CGRect(origin: .zero, size: renderSize)

            webView.takeSnapshot(with: config) { [weak self] image, error in
                guard let self else { return }

                if let error {
                    self.continuation?.resume(throwing: error)
                    self.continuation = nil
                    return
                }

                guard
                    let image            = image,
                    let tiff            = image.tiffRepresentation,
                    let bitmapImage     = NSBitmapImageRep(data: tiff),
                    let pngData         = bitmapImage
                        .representation(using: .png, properties: [:])
                else {
                    self.continuation?.resume(
                        throwing: NSError(
                            domain: "SVGToPNGRenderer",
                            code: 1,
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "Failed to convert snapshot to PNG data."
                            ]
                        )
                    )
                    self.continuation = nil
                    return
                }

                self.continuation?.resume(returning: pngData)
                self.continuation = nil
            }
        }

        func webView(_ webView: WKWebView,
                     didFail navigation: WKNavigation!,
                     withError error: Error)
        {
            continuation?.resume(throwing: error)
            continuation = nil
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error)
        {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

// MARK: - SwiftUI convenience wrapper
struct SVGImageView: View {
    let svgString: String
    @State private var pngImage: NSImage?

    var body: some View {
        Group {
            if let img = pngImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity)
            }
        }
        // ── Fire off rendering whenever svgString changes ────────────────
        .task(id: svgString) {
            do {
                let pngData = try await SVGToPNGRenderer
                    .renderToPNG(svgString: svgString)

                self.pngImage = NSImage(data: pngData)
            } catch {
                Log.io.error("❌ Failed to render SVG to PNG: \(error)")
                self.pngImage = nil
            }
        }
    }
}
