//
//  MainTabView.swift
//  Brindoo
//
//  Tab bar principale dell'app.
//  Reagisce ai deep link delle notifiche cambiando tab automaticamente.
//  Mostra pallini di notifica su Trattative (cose che aspettano te) e Chat (non letti).
//

import SwiftUI

struct MainTabView: View {

    @Environment(SessionStore.self) private var session
    @State private var router = DeepLinkRouter.shared

    @State private var pendingNegotiations: Int = 0
    @State private var unreadChats: Int = 0

    private var isClient: Bool { session.currentProfile?.role == .client }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            BoardView()
                .tag(0)
                .tabItem {
                    Label(
                        isClient ? "Esplora" : "Bacheca",
                        systemImage: isClient ? "magnifyingglass" : "list.bullet.rectangle"
                    )
                }

            NavigationStack {
                NegotiationsView()
            }
            .tag(1)
            .tabItem {
                Label("Trattative", systemImage: "arrow.left.arrow.right")
            }
            .badge(pendingNegotiations)

            ChatListView()
                .tag(2)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
                .badge(unreadChats)

            ProfileView()
                .tag(3)
                .tabItem {
                    Label("Profilo", systemImage: "person.circle")
                }
        }
        .tint(.brindooCoral)
        .environment(router)
        .task(id: router.selectedTab) { await refreshBadges() }
    }

    private func refreshBadges() async {
        async let propsTask = OfferProposalService.shared.fetchMyOngoingProposals()
        async let unreadTask = ConversationService.shared.fetchUnreadCounts()

        let proposals = (try? await propsTask) ?? []
        if let me = session.userID {
            pendingNegotiations = proposals.filter { $0.awaitingAction(by: me) }.count
        }

        let counts = (try? await unreadTask) ?? [:]
        unreadChats = counts.values.reduce(0, +)
    }
}

#Preview {
    MainTabView()
        .environment(SessionStore())
}
