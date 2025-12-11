//
//  DashboardManager.swift
//  ClashX Meta
//
//  Copyright © 2023 west2online. All rights reserved.
//

import Cocoa
import RxSwift

// SwiftUI Dashboard removed for macOS 10.14 compatibility

class DashboardManager: NSObject {

	static let shared = DashboardManager()

	override init() {
	}

	// SwiftUI is not available in macOS 10.14 compatible build
	var isSwiftUIAvailable: Bool {
		return false
	}

	var useSwiftUI: Bool {
		get {
			return false
		}
		set {
			// SwiftUI Dashboard not available in this build
			Logger.log("[Dashboard] SwiftUI Dashboard not available in macOS 10.14 compatible build")
		}
	}

	var clashWebWindowController: ClashWebViewWindowController?

	func show(_ sender: NSMenuItem?) {
		showWebWindow(sender)
	}

	func showWebWindow(_ sender: NSMenuItem?) {
		if clashWebWindowController == nil {
			clashWebWindowController = ClashWebViewWindowController.create()
			clashWebWindowController?.onWindowClose = {
				[weak self] in
				self?.clashWebWindowController = nil
			}
		}
		clashWebWindowController?.showWindow(sender)
	}
}
