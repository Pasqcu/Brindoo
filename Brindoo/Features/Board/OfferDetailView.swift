//
//  OfferDetailView.swift
//  Brindoo
//
//  Dettaglio offerta + flusso di trattativa stile Vinted.
//
//  CLIENTE non proprietario, su offerta attiva:
//    - se non ha trattativa attiva: 3 azioni (Accetta al prezzo / Fai una proposta / Nascondi)
//    - se ha trattativa pendente: vede stato e ha azioni coerenti col ruolo
//    - se accettata: pulsante apri chat
//
//  ORGANIZZATORE proprietario:
//    - vede pulsanti gestione offerta (pausa/elimina)
//    - vede lista delle "Proposte ricevute" con azioni per ciascuna
//

import SwiftUI
import StoreKit

struct OfferDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var toastCenter: BrindooToastCenter

    let offer: ServiceOffer

    @State private var categories: [ServiceCategory] = []
    @State private var organizerProfile: Profile?
    /// Foto del portfolio dell'organizzatore mostrate nella galleria in alto.
    @State private var portfolioUrls: [String] = []
    /// Pacchetti prezzo dell'offerta (Base / Completo / Premium).
    @State private var packages: [OfferPackage] = []
    @State private var navigateToChat: Conversation?
    @State private var chatPartner: Profile?

    @State private var currentStatus: ServiceOfferStatus
    @State private var isUpdating: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showReport: Bool = false

    // Trattativa lato cliente: una sola attiva
    @State private var myProposal: OfferProposal?
    @State private var myProposalLastRound: OfferProposalRound?

    // Lato organizzatore: lista proposte ricevute con ultimo round per ognuna
    @State private var receivedProposals: [OfferProposal] = []
    @State private var lastRoundsMap: [UUID: OfferProposalRound] = [:]
    @State private var clientProfilesMap: [UUID: Profile] = [:]

    @State private var showNegotiateSheet: NegotiateOfferView.Mode?
    @State private var actionError: String?

    // Preferiti
    @State private var isFavorite: Bool = false

    // Cartolina di condivisione
    @State private var isPreparingShare: Bool = false
    @State private var shareItems: SharePayload?

    // Sposta data + festa per l'accordo
    @State private var moveDateTarget: OfferProposal?
    @State private var showConfetti: Bool = false

    private struct SharePayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    /// Callback chiamato quando l'offerta viene modificata o cancellata.
    var onChange: (() -> Void)?

    init(offer: ServiceOffer, onChange: (() -> Void)? = nil) {
        self.offer = offer
        self._currentStatus = State(initialValue: offer.status)
        self.onChange = onChange
    }

    private var isOwnOffer: Bool {
        session.userID == offer.organizerId
    }

    private var isClient: Bool {
        session.currentProfile?.role == .client
    }

    private var canClientInteract: Bool {
        isClient && !isOwnOffer && currentStatus == .active
    }

    /// Copertina dell'offerta seguita dalle foto del portfolio (senza doppioni).
    private var galleryUrls: [String] {
        var urls: [String] = []
        if let cover = offer.imageUrl { urls.append(cover) }
        for u in portfolioUrls where !urls.contains(u) { urls.append(u) }
        return urls
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                if !galleryUrls.isEmpty {
                    OfferPhotoGallery(urls: galleryUrls)
                }

                OfferHeaderSection(
                    offer: offer,
                    currentStatus: currentStatus,
                    organizerProfile: organizerProfile
                )

                Divider()

                if !categories.isEmpty {
                    OfferCategoriesSection(categories: categories)
                }

                OfferInfoSection(offer: offer)

                OfferDescriptionSection(text: offer.description)

                // Vetrina pacchetti in sola lettura per proprietario e offerte
                // in pausa; la versione selezionabile vive nelle azioni cliente.
                if !packages.isEmpty && !canClientInteract {
                    OfferPackagesDisplay(packages: packages)
                }

                if let error = actionError {
                    errorBanner(error)
                }

                if canClientInteract {
                    Divider()
                    ClientNegotiationSection(
                        offer: offer,
                        proposal: myProposal,
                        organizerProfile: organizerProfile,
                        packages: packages,
                        onAcceptAtPrice: { price, label in
                            Task { await acceptAtPrice(price, label: label) }
                        },
                        onProposeNew: { showNegotiateSheet = .openAsClient(offer: offer) },
                        onHide: { Task { await dismissOffer() } },
                        onAccept: { p in Task { await acceptProposal(p) } },
                        onReject: { p in Task { await rejectProposal(p) } },
                        onCounter: { p in showNegotiateSheet = .counter(proposal: p, role: .client, offer: offer) },
                        onWithdraw: { p in Task { await withdrawProposal(p) } },
                        onOpenChat: { org in Task { await openChat(with: org) } },
                        onMarkBooking: { p, status in Task { await markBooking(p, status) } },
                        onMoveDate: { p in moveDateTarget = p },
                        onAddToCalendar: { p in Task { await addToCalendar(p) } },
                        onReviewSubmitted: { Task { await loadData() } }
                    )
                }

                if isOwnOffer {
                    Divider()
                    ownerControls
                    ReceivedProposalsSection(
                        offer: offer,
                        proposals: receivedProposals,
                        clientProfiles: clientProfilesMap,
                        onAccept: { p in Task { await acceptProposal(p) } },
                        onReject: { p in Task { await rejectProposal(p) } },
                        onCounter: { p in showNegotiateSheet = .counter(proposal: p, role: .organizer, offer: offer) },
                        onOpenChat: { client in Task { await openChat(with: client) } },
                        onMarkBooking: { p, status in Task { await markBooking(p, status) } },
                        onMoveDate: { p in moveDateTarget = p },
                        onAddToCalendar: { p in Task { await addToCalendar(p) } }
                    )
                }
            }
            .padding(BrindooSpacing.md)
            .brindooReadableWidth()
        }
        .overlay {
            if showConfetti {
                BrindooConfettiView()
            }
        }
        .background(Color.brindooBackground)
        .navigationTitle("Offerta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await prepareShareCard() }
                } label: {
                    if isPreparingShare {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.brindooCoral)
                    }
                }
                .disabled(isPreparingShare)
                .accessibilityLabel("Condividi offerta")
            }
            if isClient && !isOwnOffer {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: BrindooSpacing.sm) {
                        Button {
                            Task { await toggleFavorite() }
                        } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(isFavorite ? Color.brindooCoral : Color.brindooTextSecondary)
                        }
                        .accessibilityLabel(isFavorite ? "Rimuovi dai preferiti" : "Salva nei preferiti")

                        Menu {
                            Button(role: .destructive) {
                                showReport = true
                            } label: {
                                Label("Segnala offerta", systemImage: "exclamationmark.bubble")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                        .accessibilityLabel("Altre opzioni")
                    }
                }
            }
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(
                targetType: .offer,
                targetId: offer.id,
                targetLabel: "questa offerta"
            )
        }
        .sheet(item: $shareItems) { payload in
            ActivityShareSheet(items: payload.items)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $moveDateTarget) { proposal in
            MoveEventDateSheet(proposal: proposal) { newDate in
                Task { await moveEventDate(proposal, to: newDate) }
            }
        }
        .task { await loadData() }
        .navigationDestination(item: $navigateToChat) { conv in
            if let partner = chatPartner {
                ChatView(conversation: conv, otherUser: partner)
            }
        }
        .sheet(item: $showNegotiateSheet) { mode in
            NegotiateOfferView(mode: mode) {
                Task { await loadData() }
            }
        }
        .confirmationDialog(
            "Eliminare questa offerta?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Elimina", role: .destructive) {
                Task { await deleteOffer() }
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("L'azione non può essere annullata.")
        }
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: BrindooSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message).font(BrindooFont.bodySmall)
        }
        .foregroundStyle(Color.brindooError)
        .padding(BrindooSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooError.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
    }

    // MARK: - Lato organizzatore: gestione + proposte ricevute

    @ViewBuilder
    private var ownerControls: some View {
        VStack(spacing: BrindooSpacing.sm) {
            BrindooButton(
                currentStatus == .active ? "Metti in pausa" : "Riattiva offerta",
                style: .secondary,
                size: .medium,
                isLoading: isUpdating
            ) {
                Task { await togglePause() }
            }

            BrindooButton(
                "Elimina offerta",
                style: .destructive,
                size: .medium
            ) {
                showDeleteConfirm = true
            }
        }
    }

    // MARK: - Cartolina di condivisione

    /// Prepara l'immagine-cartolina dell'offerta e apre il foglio di
    /// condivisione (immagine + link). In caso di problemi condivide solo il link.
    private func prepareShareCard() async {
        isPreparingShare = true
        defer { isPreparingShare = false }

        let url = URL(string: "https://brindoo.app/o/\(offer.id.uuidString)")!
        let cover = await ShareCardRenderer.loadImage(from: offer.imageUrl)
        let card = OfferShareCard(
            title: offer.title,
            priceDisplay: offer.priceDisplay,
            organizerName: organizerProfile?.fullName,
            cover: cover
        )

        if let image = ShareCardRenderer.render(card) {
            shareItems = SharePayload(items: [image, url])
        } else {
            shareItems = SharePayload(items: [url])
        }
    }

    // MARK: - Actions

    private func loadData() async {
        do {
            categories = try await ServiceOfferService.shared.fetchOfferCategories(offerId: offer.id)
        } catch { BrindooLog.error("\(error)") }

        do {
            organizerProfile = try await ProfileService.shared.fetchProfile(userID: offer.organizerId)
        } catch { BrindooLog.error("\(error)") }

        // Foto del portfolio per la galleria (best-effort, massimo 6).
        if let items = try? await PortfolioService.shared.fetchPortfolio(organizerId: offer.organizerId) {
            portfolioUrls = items.prefix(6).map { $0.imageUrl }
        }

        // Pacchetti prezzo (best-effort).
        packages = (try? await OfferPackageService.shared.fetchPackages(offerId: offer.id)) ?? []

        // Cliente: carica la sua trattativa attiva + stato preferito + traccia view.
        if canClientInteract {
            do {
                myProposal = try await OfferProposalService.shared.fetchMyActiveProposal(forOffer: offer.id)
                if let p = myProposal {
                    myProposalLastRound = try await OfferProposalService.shared.fetchLastRound(proposalId: p.id)
                }
            } catch { BrindooLog.error("\(error)") }

            isFavorite = (try? await OfferFavoriteService.shared.isFavorite(offerId: offer.id)) ?? false

            // Traccia view (best-effort, ignora errori).
            await AnalyticsService.shared.trackOfferView(offerId: offer.id)
        }

        // Organizzatore proprietario: carica le proposte ricevute
        if isOwnOffer {
            do {
                receivedProposals = try await OfferProposalService.shared.fetchProposals(forOffer: offer.id)
                await loadClientsAndRounds(for: receivedProposals)
            } catch { BrindooLog.error("\(error)") }
        }
    }

    private func toggleFavorite() async {
        let target = !isFavorite
        isFavorite = target // optimistic
        do {
            if target {
                try await OfferFavoriteService.shared.add(offerId: offer.id)
            } else {
                try await OfferFavoriteService.shared.remove(offerId: offer.id)
            }
        } catch {
            isFavorite = !target // rollback
            BrindooLog.error("\(error)")
        }
    }

    private func loadClientsAndRounds(for proposals: [OfferProposal]) async {
        await withTaskGroup(of: (UUID, Profile?, OfferProposalRound?).self) { group in
            for p in proposals {
                group.addTask {
                    let profile = try? await ProfileService.shared.fetchProfile(userID: p.clientId)
                    let round = try? await OfferProposalService.shared.fetchLastRound(proposalId: p.id)
                    return (p.id, profile, round)
                }
            }
            for await (proposalId, profile, round) in group {
                if let p = proposals.first(where: { $0.id == proposalId }) {
                    if let profile { clientProfilesMap[p.clientId] = profile }
                }
                if let round { lastRoundsMap[proposalId] = round }
            }
        }
    }

    /// Accetta al prezzo dato (base o di un pacchetto). L'etichetta del
    /// pacchetto, se presente, finisce nel messaggio della proposta.
    private func acceptAtPrice(_ price: Double, label: String?) async {
        actionError = nil
        do {
            _ = try await OfferProposalService.shared.openProposal(
                offer: offer,
                price: price,
                message: label
            )
            await loadData()
        } catch {
            actionError = "Impossibile inviare la proposta."
            BrindooLog.error("\(error)")
        }
    }

    private func acceptProposal(_ proposal: OfferProposal) async {
        actionError = nil
        do {
            let conv = try await OfferProposalService.shared.accept(proposal: proposal)
            BrindooHaptics.notify(.success)

            // Festa! Coriandoli per l'accordo raggiunto, poi si apre la chat.
            showConfetti = true
            await loadData()
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            showConfetti = false

            if let conv {
                // Per il cliente l'altro è l'organizzatore, per l'organizzatore è il cliente.
                if session.userID == proposal.clientId {
                    chatPartner = organizerProfile
                } else {
                    chatPartner = clientProfilesMap[proposal.clientId]
                }
                navigateToChat = conv
            }
        } catch {
            actionError = "Impossibile accettare."
            BrindooLog.error("\(error)")
        }
    }

    /// Sposta (o fissa) la data dell'evento e avvisa l'altra parte in chat.
    private func moveEventDate(_ proposal: OfferProposal, to newDate: String) async {
        do {
            try await OfferProposalService.shared.updateEventDate(
                proposal: proposal,
                newDate: newDate,
                offerTitle: offer.title
            )
            BrindooHaptics.notify(.success)
            toastCenter.show(BrindooToast("Data aggiornata", message: "L'altra parte è stata avvisata in chat.", style: .success))
            await loadData()
        } catch {
            toastCenter.show(BrindooToast("Impossibile spostare la data", message: "Controlla la connessione e riprova.", style: .error))
            BrindooLog.error("\(error)")
        }
    }

    /// Aggiunge l'evento confermato al calendario dell'iPhone.
    private func addToCalendar(_ proposal: OfferProposal) async {
        guard let day = proposal.eventDate, !day.isEmpty else { return }
        do {
            try await CalendarService.addAllDayEvent(
                title: "🎉 \(offer.title) — Brindoo",
                dayString: day,
                notes: "Evento concordato su Brindoo per \(proposal.currentPriceDisplay)."
            )
            BrindooHaptics.notify(.success)
            toastCenter.show(BrindooToast("Aggiunto al calendario", style: .success))
        } catch {
            toastCenter.show(BrindooToast(
                "Calendario non disponibile",
                message: (error as? CalendarServiceError)?.errorDescription ?? "Riprova.",
                style: .error
            ))
        }
    }

    private func markBooking(_ proposal: OfferProposal, _ status: BookingStatus) async {
        actionError = nil
        do {
            try await OfferProposalService.shared.updateBookingStatus(proposalId: proposal.id, booking: status)
            if status == .cancelled {
                LocalReminderService.cancelReminder(proposalId: proposal.id)
            }
            BrindooHaptics.notify(status == .completed ? .success : .warning)
            await loadData()
            // Momento positivo: chiedi una valutazione su App Store.
            if status == .completed {
                try? await Task.sleep(nanoseconds: 800_000_000)
                requestReview()
            }
        } catch {
            actionError = "Impossibile aggiornare l'appuntamento."
            BrindooLog.error("\(error)")
        }
    }

    private func rejectProposal(_ proposal: OfferProposal) async {
        actionError = nil
        do {
            try await OfferProposalService.shared.reject(proposal: proposal)
            await loadData()
        } catch {
            actionError = "Impossibile rifiutare."
            BrindooLog.error("\(error)")
        }
    }

    private func withdrawProposal(_ proposal: OfferProposal) async {
        actionError = nil
        do {
            try await OfferProposalService.shared.withdraw(proposal: proposal)
            await loadData()
        } catch {
            actionError = "Impossibile ritirare."
            BrindooLog.error("\(error)")
        }
    }

    private func dismissOffer() async {
        actionError = nil
        do {
            try await OfferDismissalService.shared.dismiss(offerId: offer.id)
            onChange?()
            dismiss()
        } catch {
            actionError = "Impossibile nascondere."
            BrindooLog.error("\(error)")
        }
    }

    private func togglePause() async {
        isUpdating = true
        defer { isUpdating = false }
        let next: ServiceOfferStatus = (currentStatus == .active) ? .paused : .active
        do {
            try await ServiceOfferService.shared.updateStatus(offerId: offer.id, status: next)
            currentStatus = next
            onChange?()
        } catch {
            toastCenter.show(BrindooToast("Impossibile aggiornare l'offerta", message: "Controlla la connessione e riprova.", style: .error))
            BrindooLog.error("\(error)")
        }
    }

    private func deleteOffer() async {
        do {
            try await ServiceOfferService.shared.deleteOffer(offerId: offer.id)
            onChange?()
            dismiss()
        } catch {
            toastCenter.show(BrindooToast("Impossibile eliminare l'offerta", message: "Controlla la connessione e riprova.", style: .error))
            BrindooLog.error("\(error)")
        }
    }

    private func openChat(with other: Profile) async {
        do {
            let conv: Conversation
            if session.currentProfile?.role == .client {
                conv = try await ConversationService.shared.findOrCreateConversationAsClient(organizerId: other.id)
            } else {
                conv = try await ConversationService.shared.findOrCreateConversationAsOrganizer(clientId: other.id)
            }
            chatPartner = other
            navigateToChat = conv
        } catch {
            toastCenter.show(BrindooToast("Impossibile aprire la chat", message: "Controlla la connessione e riprova.", style: .error))
            BrindooLog.error("\(error)")
        }
    }
}

// MARK: - Identifiable per usare .sheet(item:)
extension NegotiateOfferView.Mode: Identifiable {
    var id: String {
        switch self {
        case .openAsClient(let offer):
            return "open-\(offer.id.uuidString)"
        case .counter(let proposal, let role, _):
            return "counter-\(proposal.id.uuidString)-\(role.rawValue)"
        }
    }
}
