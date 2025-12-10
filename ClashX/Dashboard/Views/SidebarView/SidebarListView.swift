//
//  SidebarListView.swift
//  ClashX Dashboard
//
//

import SwiftUI

@available(macOS 10.15, *)
struct SidebarListView: View {

	@Binding var selection: SidebarItem?

	@State private var reloadID = UUID().uuidString


    var body: some View {
		List {
			NavigationLink(destination: OverviewView(),
						   tag: SidebarItem.overview,
						   selection: $selection) {
				SidebarLabel(item: .overview)
			}

			NavigationLink(destination: ProxiesView(),
						   tag: SidebarItem.proxies,
						   selection: $selection) {
				SidebarLabel(item: .proxies)
			}

			NavigationLink(destination: ProvidersView(),
						   tag: SidebarItem.providers,
						   selection: $selection) {
				SidebarLabel(item: .providers)
			}

			NavigationLink(destination: RulesView(),
						   tag: SidebarItem.rules,
						   selection: $selection) {
				SidebarLabel(item: .rules)
			}

			NavigationLink(destination: ConnectionsView(),
						   tag: SidebarItem.conns,
						   selection: $selection) {
				SidebarLabel(item: .conns)
			}

			NavigationLink(destination: ConfigView(),
						   tag: SidebarItem.config,
						   selection: $selection) {
				SidebarLabel(item: .config)
			}

			NavigationLink(destination: LogsView(),
						   tag: SidebarItem.logs,
						   selection: $selection) {
				SidebarLabel(item: .logs)
			}

		}
		.onAppear {
			if selection == nil {
				selection = SidebarItem.overview
			}
		}
		.listStyle(.sidebar)
		.id(reloadID)
		.onReceive(NotificationCenter.default.publisher(for: .reloadDashboard)) { _ in
			reloadID = UUID().uuidString
		}
    }
}

//struct SidebarListView_Previews: PreviewProvider {
//    static var previews: some View {
//        SidebarListView()
//    }
//}
