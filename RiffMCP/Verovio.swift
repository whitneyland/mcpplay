import Foundation
import AppKit

class Verovio {
    static func validateVerovioIntegration() -> Bool {
        // Test creating a Verovio toolkit instance
        let toolkit = vrvToolkit_constructor()
        guard toolkit != nil else {
            print("Failed to create Verovio toolkit")
            return false
        }
        
        // Test getting version
        let version = vrvToolkit_getVersion(toolkit)
        if let versionString = version {
            let swiftVersion = String(cString: versionString)
            print("Verovio version: \(swiftVersion)")
        }
        
        // Clean up
        vrvToolkit_destructor(toolkit)
        
        print("Verovio integration test passed!")
        return true
    }
    
    static func svgFromMEI(_ meiXML: String, pageWidth: Int = 1700, pageHeight: Int = 2200) -> String? {

        // TODO: Don't use hardcoded path for Verovio resources
        let resourcePath = "/Users/lee/verovio-resources/data"
        print("Using path:", resourcePath, FileManager.default.fileExists(atPath: resourcePath))

        let toolkit = vrvToolkit_constructorResourcePath(resourcePath)
        guard toolkit != nil else {
            print("Failed to create Verovio toolkit with resource path: \(resourcePath)")
            return nil
        }
        
        // Explicitly set resource path for good measure
        let success = vrvToolkit_setResourcePath(toolkit, resourcePath)
        if !success {
            print("Warning: Failed to set resource path explicitly")
        }
        print("Created Verovio toolkit with resource path: \(resourcePath)")


        // Set options for better rendering with explicit font configuration
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
        var result = vrvToolkit_setOptions(toolkit, options)

        print("Loading provided MEI XML")
        
        // Load MEI data into Verovio
        let success1 = vrvToolkit_loadData(toolkit, meiXML)
        guard success1 else {
            print("Failed to load MEI data into Verovio")
            vrvToolkit_destructor(toolkit)
            return nil
        }
        
        print("Attempting to render SVG...")
        let generateClasses = true
        let svgPtr = vrvToolkit_renderToSVG(toolkit, 1, generateClasses) // page 1, no XML declaration
        guard let svgPtr = svgPtr else {
            print("Failed to generate SVG")
            vrvToolkit_destructor(toolkit)
            return nil
        }
        
        let svgString = String(cString: svgPtr)
        print("Successfully generated SVG! Length: \(svgString.count)")
        
        // Debug preview of SVG content
        if svgString.count > 100 {
            let preview = String(svgString.prefix(200))
            print("SVG preview: \(preview)...")
        }

        vrvToolkit_destructor(toolkit)

        return svgString
    }
    
    static func svgFromSimpleTestXml() -> String? {
        // Simple MEI XML with a few test notes (C, E, G)
        let meiXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0">
          <meiHead>
            <fileDesc>
              <titleStmt>
                <title>RiffMCP Test</title>
              </titleStmt>
              <pubStmt/>
            </fileDesc>
          </meiHead>
          <music>
            <body>
              <mdiv>
                <score>
                  <scoreDef meter.count="4" meter.unit="4" key.sig="0">
                    <staffGrp>
                      <staffDef n="1" lines="5" clef.shape="G" clef.line="2"/>
                    </staffGrp>
                  </scoreDef>
                  <section>
                    <measure n="1">
                      <staff n="1">
                        <layer n="1">
                          <note pname="c" oct="4" dur="4"/>
                          <note pname="e" oct="4" dur="4"/>
                          <note pname="g" oct="4" dur="4"/>
                          <note pname="c" oct="5" dur="4"/>
                        </layer>
                      </staff>
                    </measure>
                  </section>
                </score>
              </mdiv>
            </body>
          </music>
        </mei>        
        """
        return svgFromMEI(meiXML, pageWidth: 2200, pageHeight: 2200)
    }
}
