import Foundation
import WebKit
import AppKit
import SwiftUI

// Headless SVG rendering that we can use to serve images without UI
struct SVGToPNGRenderer: NSViewRepresentable {
    let svgString: String
    @Binding var pngImage: NSImage?
    let renderSize: CGSize                // concrete size chosen once

    /// Init: caller size ▶︎ SVG intrinsic ▶︎ fallback
    init(_ svgString: String,
         _ pngImage: Binding<NSImage?>,
         requestedSize: CGSize? = nil)
    {
        self.svgString  = svgString
        self._pngImage  = pngImage

        // ── extract width / height from the <svg> tag, if any ──────────────
        var intrinsicSize: CGSize? = nil
        if let (w, h) = Util.extractDimensions(from: svgString) {
            intrinsicSize = CGSize(width: w, height: h)
//            print(String(format: "SD:svgString   : %04d x %04d", w, h))
        }

        // ── final render size decision ─────────────────────────────────────
        self.renderSize =
              requestedSize                       // caller override
           ?? intrinsicSize                       // SVG says so
           ?? CGSize(width: 1700, height: 2200)   // last-ditch default

//        print(String(format: "SD:SVGToPNG    : %.0f x %.0f", renderSize.width, renderSize.height))
    }

    // Convenience for views that need the SVG’s own size
    static func intrinsicSize(of svgString: String) -> CGSize? {
        if let (w, h) = Util.extractDimensions(from: svgString) {
            return CGSize(width: w, height: h)
        }
        return nil
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: CGRect(origin: .zero, size: renderSize))
        webView.navigationDelegate = context.coordinator
        // Don't set isHidden = true as it prevents proper rendering for snapshots
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.svgString = svgString
        context.coordinator.pngImage = $pngImage
        context.coordinator.renderSize = renderSize
        context.coordinator.renderSVGToPNG(webView: nsView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var svgString: String = ""
        var pngImage: Binding<NSImage?>?
        var lastLoadedSVG: String = ""
        var renderSize: CGSize = .zero
        
        func getRenderSize() -> CGSize {
            return renderSize
        }
        
        func renderSVGToPNG(webView: WKWebView) {
            guard !svgString.isEmpty else { return }
            
            // Prevent unnecessary reloads
            guard svgString != lastLoadedSVG else { return }
            
            lastLoadedSVG = svgString
            
            
            let htmlContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    * { margin: 0; padding: 0; box-sizing: border-box; }
                    body { 
                        background: white; 
                        font-family: Arial, sans-serif;
                        width: fit-content;
                        height: fit-content;
                    }
                    svg { 
                        display: block; 
                        width: auto !important;
                        height: auto !important;
                    }
                </style>
            </head>
            <body>
                \(svgString)                
            </body>
            </html>
            """
            
            webView.loadHTMLString(htmlContent, baseURL: nil)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.captureWebViewAsPNG(webView: webView)
        }
        


        private func captureWebViewAsPNG(webView: WKWebView) {
            let config = WKSnapshotConfiguration()
            config.rect = CGRect(origin: .zero, size: renderSize)

            webView.takeSnapshot(with: config) { [weak self] image, error in
                guard let self else { return }

                if let error { print("❌ Snapshot failed: \(error)"); return }
                guard let image else { print("❌ Snapshot failed: no image"); return }

                // Update SwiftUI view
                self.pngImage?.wrappedValue = image

                // ───── debug stuff ───
//                let tmp = FileManager.default.temporaryDirectory
//                let svgURL = tmp.appendingPathComponent("debug_output.svg")
//                let pngURL = tmp.appendingPathComponent("debug_output.png")
//
//                try? self.svgString.write(to: svgURL, atomically: true, encoding: .utf8)
//
//                if let tiff = image.tiffRepresentation,
//                   let rep  = NSBitmapImageRep(data: tiff),
//                   let png  = rep.representation(using: .png, properties: [:])
//                {
//                    print("SD:PNG size: \(rep.pixelsWide) × \(rep.pixelsHigh)")
//                    try? png.write(to: pngURL)
//                }
            }
        }
    }
    
    @MainActor
    static func renderToPNG(svgString: String, size: CGSize? = nil) async throws -> Data {
        // Determine the rendering size
        let renderSize: CGSize
        if let providedSize = size {
            renderSize = providedSize
        } else if let (w, h) = Util.extractDimensions(from: svgString) {
            renderSize = CGSize(width: w, height: h)
        } else {
            renderSize = CGSize(width: 1700, height: 2200) // Default fallback
        }

        // Create a web view offscreen
        let webView = WKWebView(frame: CGRect(origin: .zero, size: renderSize))
        
        // Use a continuation to bridge the callback
        return try await withCheckedThrowingContinuation { continuation in
            // Create a coordinator to handle web view delegate methods
            let coordinator = HeadlessCoordinator(
                svgString: svgString,
                renderSize: renderSize,
                continuation: continuation
            )
            
            webView.navigationDelegate = coordinator
            
            // Keep the coordinator alive
            objc_setAssociatedObject(webView, "headlessCoordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)

            // Load the SVG content
            let htmlContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    * { margin: 0; padding: 0; box-sizing: border-box; }
                    body { background: white; width: fit-content; height: fit-content; }
                    svg { display: block; }
                </style>
            </head>
            <body>
                \(svgString)
            </body>
            </html>
            """
            webView.loadHTMLString(htmlContent, baseURL: nil)
        }
    }
}

// A new coordinator class specifically for the headless operation
private class HeadlessCoordinator: NSObject, WKNavigationDelegate {
    let svgString: String
    let renderSize: CGSize
    var continuation: CheckedContinuation<Data, Error>?

    init(svgString: String, renderSize: CGSize, continuation: CheckedContinuation<Data, Error>) {
        self.svgString = svgString
        self.renderSize = renderSize
        self.continuation = continuation
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let config = WKSnapshotConfiguration()
        config.rect = CGRect(origin: .zero, size: renderSize)

        webView.takeSnapshot(with: config) { [weak self] image, error in
            guard let self = self else { return }
            
            if let error = error {
                self.continuation?.resume(throwing: error)
                self.continuation = nil
                return
            }
            
            guard let image = image else {
                self.continuation?.resume(throwing: NSError(domain: "SVGToPNGRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Snapshot failed to produce an image."]))
                self.continuation = nil
                return
            }

            // Convert NSImage to PNG Data
            guard let tiffRepresentation = image.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
                  let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                self.continuation?.resume(throwing: NSError(domain: "SVGToPNGRenderer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert NSImage to PNG data."]))
                self.continuation = nil
                return
            }
            
            self.continuation?.resume(returning: pngData)
            self.continuation = nil
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

// SwiftUI view that displays the PNG image
struct SVGImageView: View {
    let svgString: String
    @State private var pngImage: NSImage?

    // compute once per View
    private var intrinsicSize: CGSize {
        if let (w, h) = Util.extractDimensions(from: svgString) {
            return CGSize(width: w, height: h)
        }
        return CGSize(width: 1700, height: 2200)   // fallback
    }

    var body: some View {
        GeometryReader { _ in
            if let img = pngImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(
            SVGToPNGRenderer(svgString,
                             $pngImage,
                             requestedSize: nil)     // ← nil → use intrinsic
                .frame(width: intrinsicSize.width,
                       height: intrinsicSize.height)
                .opacity(0.01)
                .allowsHitTesting(false)
        )
    }
}
