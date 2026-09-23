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
    @State private var network = NetworkMonitor.shared

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
        // Consenso legale con prova sul server: prima i Termini (tutti),
        // poi la dichiarazione del professionista. Bloccanti finché non firmati.
        .task(id: session.currentProfile?.id) {
            // Chi ha già accettato nell'onboarding su questo dispositivo non
            // deve rifirmare: registriamo la prova sul server in silenzio.
            // Il pannello resta per i casi rimanenti (nuovo dispositivo,
            // Termini aggiornati).
            guard let p = session.currentProfile, p.needsTermsAcceptance,
                  p.termsVersion == nil,
                  !(UserDefaults.standard.string(forKey: "brindoo.legal.acceptedTermsAt") ?? "").isEmpty
            else { return }
            if let updated = try? await ProfileService.shared.recordTermsAcceptance() {
                session.updateLocalProfile(updated)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { session.currentProfile?.needsTermsAcceptance == true },
            set: { _ in }
        )) {
            LegalConsentGate()
        }
        .fullScreenCover(isPresented: Binding(
            get: {
                guard let p = session.currentProfile, !session.isChangingRole else { return false }
                return !p.needsTermsAcceptance && p.needsProfessionalDeclaration
            },
            set: { _ in }
        )) {
            ProfessionalDeclarationGate()
        }
        .task(id: router.selectedTab) { await refreshBadges() }
        // Tornata la linea, la coda si svuota da sola.
        .onChange(of: network.isOnline) { _, online in
            guard online else { return }
            Task { await OfflineOutboxService.shared.flush() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Al rientro in app i conteggi (e il numerino sull'icona)
            // si riallineano subito alla realtà.
            if newPhase == .active {
                Task { await refreshBadges() }
                // Un blocco messo dall'altra parte mentre l'app era chiusa
                // deve valere subito, non al prossimo login.
                Task { await BlockService.shared.loadBlocks() }
                // Cose scritte senza linea: si riprova appena l'app torna viva.
                Task { await OfflineOutboxService.shared.flush() }
                // Ricerche salvate con avviso: controllo silenzioso delle
                // novità (al massimo una volta l'ora).
                if isClient {
                    Task { await SavedSearchService.shared.checkForNewResults() }
                }
            }
        }
        .task(id: session.currentProfile?.isPro) {
            // Pro finito: l'icona dorata torna la classica. Prima restava
            // d'oro e il tocco in Impostazioni apriva la paywall.
            guard let p = session.currentProfile, !p.isPro,
                  UIApplication.shared.alternateIconName == "AppIconPro" else { return }
            try? await UIApplication.shared.setAlternateIconName(nil)
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

    /// Promemoria degli eventi allineati agli accordi, su tutti e due i telefoni.
    private func syncReminders(_ proposals: [OfferProposal], me: UUID) async {
        let accepted = proposals.filter { $0.status == .accepted }
        guard !accepted.isEmpty else {
            await LocalReminderService.sync(with: [], offerTitles: [:], me: me)
            return
        }
        let ids = Array(Set(accepted.map(\.offerId)))
        let offers = (try? await ServiceOfferService.shared.fetchOffers(ids: ids)) ?? []
        let titles = Dictionary(offers.map { ($0.id, $0.title) }, uniquingKeysWith: { a, _ in a })
        await LocalReminderService.sync(with: accepted, offerTitles: titles, me: me)
    }

    private func refreshBadges() async {
        async let propsTask = OfferProposalService.shared.fetchMyOngoingProposals()
        async let unreadTask = ConversationService.shared.fetchUnreadCounts()

        let loaded = try? await propsTask
        let proposals = loaded ?? []
        if let me = session.userID {
            pendingNegotiations = proposals.filter { $0.awaitingAction(by: me) }.count
            // Solo con la lista vera: senza linea non si cancella nulla.
            if let loaded {
                await syncReminders(loaded, me: me)
            }
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
