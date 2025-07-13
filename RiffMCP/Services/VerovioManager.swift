//
//  VerovioManager.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/14/25.
//

import Foundation

// Owns the C toolkit pointer, sets options, renders, cleans up.
// Keep unmanaged pointer isolated behind one boundary and guarantee deinit runs on @MainActor.
@MainActor
final class VerovioManager {
    static let shared = VerovioManager()
    
    private let toolkit: UnsafeMutableRawPointer
    
    private init() {
        guard
            let path = Bundle.main.path(forResource: "data",
                                         ofType: nil,
                                         inDirectory: "Verovio"),
            let tk   = vrvToolkit_constructorResourcePath(path)
        else { fatalError("Verovio: couldn't load resources") }
        
        _ = vrvToolkit_setResourcePath(tk, path)
        toolkit = tk
    }
    
    deinit { 
        MainActor.assumeIsolated {
            vrvToolkit_destructor(toolkit)
        }
    }
    
    func svg(from mei: String,
             pageWidth: Int = 1700,
             pageHeight: Int = 2200) -> String? {
        
        let options = """
        {
          "pageWidth": \(pageWidth),
          "pageHeight": \(pageHeight),
          "scale": 40,
          "adjustPageHeight": true,
          "font": "Leipzig",
          "fontFallback": "Leipzig",
          "svgCss": "path { stroke: #000000; }"
        }
        """
        _ = vrvToolkit_setOptions(toolkit, options)
        
        guard vrvToolkit_loadData(toolkit, mei) else { return nil }
        guard let ptr = vrvToolkit_renderToSVG(toolkit, 1, true) else { return nil }
        
        let rawSVG = String(cString: ptr)
        return Verovio.postProcessSvgString(rawSVG)
    }
}
