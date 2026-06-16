//
//  MainTabView.swift
//  Brindoo
//
//  Tab bar principale dell'app.
//  Reagisce ai deep link delle notifiche cambiando tab automaticamente.
//

import SwiftUI

struct MainTabView: View {

    @State private var router = DeepLinkRouter.shared

    var body: some View {
        TabView(selection: $router.selectedTab) {
            BoardView()
                .tag(0)
                .tabItem {
                    Label("Bacheca", systemImage: "list.bullet.rectangle")
                }

            NavigationStack {
                NegotiationsView()
            }
            .tag(1)
            .tabItem {
                Label("Trattative", systemImage: "arrow.left.arrow.right")
            }

            ChatListView()
                .tag(2)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }

            ProfileView()
                .tag(3)
                .tabItem {
                    Label("Profilo", systemImage: "person.circle")
                }
        }
        .tint(.brindooCoral)
        .environment(router)
    }
}

#Preview {
    MainTabView()
        .environment(SessionStore())
}
