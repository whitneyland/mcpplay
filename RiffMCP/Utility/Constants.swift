//
//  Constants.swift
//  RiffMCP
//
//  Created by Lee Whitney on 7/15/25.
//

import Foundation
import CoreGraphics

/// Application-wide constants
struct Constants {
    
    /// Verovio rendering configuration
    struct Verovio {
        /// Default page width for SVG rendering (in Verovio units)
        static let defaultPageWidth: Int = 1700
        
        /// Default page height for SVG rendering (in Verovio units)
        static let defaultPageHeight: Int = 2200
        
        /// Default page size as CGSize for rendering operations
        static let defaultPageSize = CGSize(width: defaultPageWidth, height: defaultPageHeight)
    }
}