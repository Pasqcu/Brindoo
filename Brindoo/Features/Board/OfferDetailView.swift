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

    /// Parte dati (caricamenti, trattative, preferiti): vive nel ViewModel.
    @State private var vm: OfferDetailViewModel

    // Stato di sola interfaccia (pannelli, navigazione, effetti)
    @State private var navigateToChat: Conversation?
    @State private var chatPartner: Profile?
    @State private var showDeleteConfirm: Bool = false
    @State private var showReport: Bool = false
    @State private var showNegotiateSheet: NegotiateOfferView.Mode?

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
        self._vm = State(initialValue: OfferDetailViewModel(offer: offer))
        self.onChange = onChange
    }

    /// Durata della festa di coriandoli e attesa prima di chiedere la
    /// valutazione: tempi di lettura, non attese tecniche.
    private static let confettiSeconds: Double = 1.6
    private static let reviewPromptDelaySeconds: Double = 0.8

    private var isOwnOffer: Bool {
        session.userID == offer.organizerId
    }

    private var isClient: Bool {
        session.currentProfile?.role == .client
    }

    private var canClientInteract: Bool {
        isClient && !isOwnOffer && vm.currentStatus == .active
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                if !vm.galleryUrls.isEmpty {
                    OfferPhotoGallery(urls: vm.galleryUrls)
                }

                OfferHeaderSection(
                    offer: offer,
                    currentStatus: vm.currentStatus,
                    organizerProfile: vm.organizerProfile
                )

                Divider()

                if !vm.categories.isEmpty {
                    OfferCategoriesSection(categories: vm.categories)
                }

                OfferInfoSection(offer: offer)

                OfferDescriptionSection(text: offer.description)

                // Vetrina pacchetti in sola lettura per proprietario e offerte
                // in pausa; la versione selezionabile vive nelle azioni cliente.
                if !vm.packages.isEmpty && !canClientInteract {
                    OfferPackagesDisplay(packages: vm.packages)
                }

                if let error = vm.actionError {
                    BrindooInlineError(error)
                }

                if canClientInteract {
                    Divider()
                    ClientNegotiationSection(
                        offer: offer,
                        proposal: vm.myProposal,
                        organizerProfile: vm.organizerProfile,
                        packages: vm.packages,
                        onAcceptAtPrice: { price, label in
                            Task { await vm.acceptAtPrice(price, label: label) }
                        },
                        onProposeNew: { showNegotiateSheet = .openAsClient(offer: offer) },
                        onHide: { Task { await dismissOffer() } },
                        onAccept: { p in Task { await acceptProposal(p) } },
                        onReject: { p in Task { await vm.rejectProposal(p) } },
                        onCounter: { p in showNegotiateSheet = .counter(proposal: p, role: .client, offer: offer) },
                        onWithdraw: { p in Task { await vm.withdrawProposal(p) } },
                        onOpenChat: { org in Task { await openChat(with: org) } },
                        onMarkBooking: { p, status in Task { await markBooking(p, status) } },
                        onMoveDate: { p in moveDateTarget = p },
                        onAddToCalendar: { p in Task { await addToCalendar(p) } },
                        onReviewSubmitted: { Task { await vm.loadData() } }
                    )
                    // Mentre una mossa è in volo i comandi restano fermi:
                    // niente doppio invio, e si vede che sta succedendo.
                    .disabled(vm.isActing)
                    .opacity(vm.isActing ? 0.6 : 1)
                }

                if isOwnOffer {
                    Divider()
                    ownerControls
                    ReceivedProposalsSection(
                        offer: offer,
                        proposals: vm.receivedProposals,
                        clientProfiles: vm.clientProfilesMap,
                        onAccept: { p in Task { await acceptProposal(p) } },
                        onReject: { p in Task { await vm.rejectProposal(p) } },
                        onCounter: { p in showNegotiateSheet = .counter(proposal: p, role: .organizer, offer: offer) },
                        onWithdraw: { p in Task { await vm.withdrawProposal(p) } },
                        onOpenChat: { client in Task { await openChat(with: client) } },
                        onMarkBooking: { p, status in Task { await markBooking(p, status) } },
                        onMoveDate: { p in moveDateTarget = p },
                        onAddToCalendar: { p in Task { await addToCalendar(p) } }
                    )
                    .disabled(vm.isActing)
                    .opacity(vm.isActing ? 0.6 : 1)
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
                        Image(systemName: BrindooIcon.share)
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
                            Task { await vm.toggleFavorite() }
                        } label: {
                            Image(systemName: vm.isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(vm.isFavorite ? Color.brindooCoral : Color.brindooTextSecondary)
                        }
                        .accessibilityLabel(vm.isFavorite ? "Rimuovi dai preferiti" : "Salva nei preferiti")

                        Menu {
                            Button(role: .destructive) {
                                showReport = true
                            } label: {
                                Label("Segnala offerta", systemImage: "exclamationmark.bubble")
                            }
                        } label: {
                            Image(systemName: BrindooIcon.more)
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
        .task {
            vm.configure(
                userID: session.userID,
                isOwnOffer: isOwnOffer,
                canClientInteract: canClientInteract
            )
            await vm.loadData()
        }
        .navigationDestination(item: $navigateToChat) { conv in
            if let partner = chatPartner {
                ChatView(conversation: conv, otherUser: partner)
            }
        }
        .sheet(item: $showNegotiateSheet) { mode in
            NegotiateOfferView(mode: mode) {
                Task { await vm.loadData() }
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
            Text(vm.openProposalsCount > 0
                 ? "L'azione non può essere annullata. Verranno chiuse anche \(vm.openProposalsCount) trattative ancora aperte su questa offerta."
                 : "L'azione non può essere annullata.")
        }
    }

    // MARK: - Lato organizzatore: gestione + proposte ricevute

    @ViewBuilder
    private var ownerControls: some View {
        VStack(spacing: BrindooSpacing.sm) {
            BrindooButton(
                vm.currentStatus == .active ? "Metti in pausa" : "Riattiva offerta",
                style: .secondary,
                size: .medium,
                isLoading: vm.isUpdating
            ) {
                Task { await togglePause() }
            }

            // Con accordi confermati il tasto resta spento e spiega perché:
            // meglio di un errore che arriva dopo aver toccato "Elimina".
            BrindooButton(
                "Elimina offerta",
                style: .destructive,
                size: .medium
            ) {
                showDeleteConfirm = true
            }
            .disabled(vm.hasConfirmedAgreements)

            if vm.hasConfirmedAgreements {
                Text("Non eliminabile: ci sono eventi già concordati su questa offerta. Puoi metterla in pausa per toglierla dalla bacheca.")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
            organizerName: vm.organizerProfile?.fullName,
            cover: cover
        )

        if let image = ShareCardRenderer.render(card) {
            shareItems = SharePayload(items: [image, url])
        } else {
            shareItems = SharePayload(items: [url])
        }
    }

    // MARK: - Azioni che restano alla vista
    //
    // Il ViewModel fa il lavoro sui dati e dice com'è andata; qui restano
    // festa, navigazione, avvisi e cose del telefono (calendario).

    /// Accordo raggiunto: coriandoli, poi si apre la chat.
    private func acceptProposal(_ proposal: OfferProposal) async {
        guard let result = await vm.acceptProposal(proposal) else { return }
        BrindooHaptics.notify(.success)
        showConfetti = true
        try? await Task.sleep(for: .seconds(Self.confettiSeconds))
        showConfetti = false
        chatPartner = result.partner
        navigateToChat = result.conversation
    }

    private func moveEventDate(_ proposal: OfferProposal, to newDate: String) async {
        if await vm.moveEventDate(proposal, to: newDate) {
            BrindooHaptics.notify(.success)
            toastCenter.show(BrindooToast("Data aggiornata", message: "L'altra parte è stata avvisata in chat.", style: .success))
        } else {
            toastCenter.show(BrindooToast("Impossibile spostare la data", message: BrindooText.retryHint, style: .error))
        }
    }

    private func markBooking(_ proposal: OfferProposal, _ status: BookingStatus) async {
        guard await vm.markBooking(proposal, status) else { return }
        BrindooHaptics.notify(status == .completed ? .success : .warning)
        // Momento positivo: chiedi una valutazione su App Store.
        if status == .completed {
            try? await Task.sleep(for: .seconds(Self.reviewPromptDelaySeconds))
            requestReview()
        }
    }

    private func dismissOffer() async {
        if await vm.dismissOffer() {
            onChange?()
            dismiss()
        }
    }

    private func togglePause() async {
        if await vm.togglePause() {
            onChange?()
        } else {
            toastCenter.show(BrindooToast("Impossibile aggiornare l'offerta", message: BrindooText.retryHint, style: .error))
        }
    }

    private func deleteOffer() async {
        // Il server rifiuta la cancellazione se ci sono accordi confermati:
        // porterebbe via anche prezzo, data e acconto di impegni presi.
        if vm.hasConfirmedAgreements {
            toastCenter.show(BrindooToast(
                "Offerta con accordi confermati",
                message: "Non si può eliminare finché ci sono eventi concordati. Puoi toglierla dalla bacheca.",
                style: .error
            ))
            return
        }
        if await vm.deleteOffer() {
            onChange?()
            dismiss()
        } else {
            toastCenter.show(BrindooToast("Impossibile eliminare l'offerta", message: BrindooText.retryHint, style: .error))
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
            toastCenter.show(BrindooToast("Impossibile aprire la chat", message: BrindooText.retryHint, style: .error))
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
