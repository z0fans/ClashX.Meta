//
//  ColorExtension.swift
//  ClashX Dashboard
//
//

import Foundation
import SwiftUI

@available(macOS 10.15, *)
extension Color {
	init(compatible nsColor: NSColor) {
		if #available(macOS 12.0, *) {
			self.init(nsColor: nsColor)
		} else {
			self.init(nsColor.usingColorSpace(.sRGB) ?? .black)
		}
	}
}
