//
//  DashboardView.swift
//  ClashX Dashboard
//
//

import SwiftUI

@available(macOS 10.15, *)
class HideProxyNames: ObservableObject, Identifiable {
	let id = UUID().uuidString
	@Published var hide = false
}

@available(macOS 10.15, *)
struct DashboardView: View {

	private let runningState = NotificationCenter.default.publisher(for: .init("ClashRunningStateChanged"))
	@State private var isRunning = false

	var body: some View {
		Group {
			NavigationView {
				SidebarView()
				EmptyView()
			}
		}
		.onReceive(runningState) { _ in
			isRunning = ConfigManager.shared.isRunning
		}

	}
}

@available(macOS 10.15, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
		DashboardView()
    }
}
