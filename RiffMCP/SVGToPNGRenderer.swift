import Foundation
import WebKit
import AppKit
import SwiftUI


struct SVGToPNGRenderer: NSViewRepresentable {
    let svgString: String
    @Binding var pngImage: NSImage?
    let renderSize: CGSize
    static var count = 0

    init(_ svgString: String, _ pngImage: Binding<NSImage?>, _ width: CGFloat = 2200, _ height: CGFloat = 1700) {
        self.svgString = svgString
        self._pngImage = pngImage
        self.renderSize = CGSize(width: width, height: height)

        print(String(format: "SD:SVGToPNG    : %04.0f x %04.0f", width, height))
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
            // Get the actual content dimensions
            webView.evaluateJavaScript("document.body.scrollWidth") { width, _ in
                webView.evaluateJavaScript("document.body.scrollHeight") { height, _ in
                    let contentWidth = width as? Double ?? self.getRenderSize().width
                    let contentHeight = height as? Double ?? self.getRenderSize().height
                    
                    let config = WKSnapshotConfiguration()
                    config.rect = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
                    
                    webView.takeSnapshot(with: config) { [weak self] image, error in
                        if let image = image {
                            self?.pngImage?.wrappedValue = image
                        }
                    }
                }
            }
        }
    }
}

// SwiftUI view that displays the PNG image
struct SVGImageView: View {
    let svgString: String
    @State private var pngImage: NSImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let pngImage = pngImage {
                    Image(nsImage: pngImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.5)
                        )
                }

                // Hidden WebView for rendering - use opacity instead of offset
                SVGToPNGRenderer(svgString, $pngImage, 1700, 2200)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .printCount(String(format: "SD:SVGImageView: %04.0f x %04.0f", geometry.size.width, geometry.size.height))
                    .opacity(0.01)  // Nearly invisible but still rendered
                    .allowsHitTesting(false)  // Don't interfere with UI
                    .zIndex(-1)  // Behind other content
            }
        }
    }
}
