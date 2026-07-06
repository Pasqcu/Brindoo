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
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = DeepLinkRouter.shared

    @State private var pendingNegotiations: Int = 0
    @State private var unreadChats: Int = 0
    @State private var linkTarget: LinkTarget?

    private var isClient: Bool { session.currentProfile?.role == .client }

    /// Destinazione aperta da un link condiviso o da una notifica.
    enum LinkTarget: Identifiable {
        case offer(ServiceOffer)
        case profile(Profile)
        var id: String {
            switch self {
            case .offer(let o): return "o-\(o.id)"
            case .profile(let p): return "p-\(p.id)"
            }
        }
    }

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
        .onChange(of: scenePhase) { _, newPhase in
            // Al rientro in app i conteggi (e il numerino sull'icona)
            // si riallineano subito alla realtà.
            if newPhase == .active {
                Task { await refreshBadges() }
            }
        }
        .task(id: session.currentProfile?.id) {
            // Aggiorna (al massimo una volta al giorno) la velocità di risposta
            // mostrata sul profilo pubblico del professionista.
            await ResponseInsightsService.shared.updateIfNeeded(profile: session.currentProfile)
        }
        .onChange(of: router.pendingProfileId) { _, id in
            guard let id else { return }
            Task {
                if let p = try? await ProfileService.shared.fetchProfile(userID: id) {
                    linkTarget = .profile(p)
                }
                router.clearPendingProfile()
            }
        }
        .onChange(of: router.pendingOfferId) { _, id in
            guard let id else { return }
            Task {
                if let o = try? await ServiceOfferService.shared.fetchOffer(id: id) {
                    linkTarget = .offer(o)
                }
                router.clearPendingOffer()
            }
        }
        .sheet(item: $linkTarget) { target in
            NavigationStack {
                switch target {
                case .offer(let offer):
                    OfferDetailView(offer: offer)
                case .profile(let profile):
                    OrganizerDetailView(organizer: profile)
                }
            }
        }
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

        // Il numerino sull'icona rispecchia le cose reali da gestire:
        // con zero sparisce (e sparisce anche la coda di notifiche vecchie).
        await NotificationService.shared.syncAppBadge(to: pendingNegotiations + unreadChats)
    }
}

#Preview {
    MainTabView()
        .environment(SessionStore())
}
