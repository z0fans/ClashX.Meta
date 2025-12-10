//
//  SwiftUIView.swift
//  
//
//

import SwiftUI

@available(macOS 10.15, *)
struct SidebarLabel: View {
	@State var item: SidebarItem
	
    var body: some View {
		Label {
			Text(item.rawValue)
		} icon: {
            Image(systemName: item.icon)
				.foregroundColor(.accentColor)
		}
    }
}

@available(macOS 10.15, *)
struct SidebarLabel_Previews: PreviewProvider {
    static var previews: some View {
		SidebarLabel(item: .overview)
    }
}
