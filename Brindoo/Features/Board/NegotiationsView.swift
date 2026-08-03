//
//  NegotiationsView.swift
//  Brindoo
//
//  Hub centralizzato per tutte le trattative attive (pending + accepted)
//  in cui l'utente corrente è coinvolto, come cliente o organizzatore.
//
//  Sezioni:
//   - "Aspettano te": proposte dove la palla è dalla tua parte
//   - "In attesa di risposta": proposte dove stai aspettando l'altra parte
//   - "Concluse": accettate
//

import SwiftUI

struct NegotiationsView: View {

    @Environment(SessionStore.self) private var session
    @EnvironmentObject private var toastCenter: BrindooToastCenter

    @State private var state: LoadState<[OfferProposal]> = .loading
    @State private var offerMap: [UUID: ServiceOffer] = [:]
    @State private var profileMap: [UUID: Profile] = [:]
    /// Affidabilità dei clienti, mostrata solo al professionista.
    @State private var clientTrust: [UUID: ClientTrust] = [:]

    private var proposals: [OfferProposal] { state.value ?? [] }
    @State private var chatTarget: ChatTarget?
    @State private var reviewTarget: Profile?

    /// Destinazione chat raggiungibile da una trattativa conclusa.
    private struct ChatTarget: Identifiable, Hashable {
        let id: UUID
        let conversation: Conversation
        let other: Profile

        static func == (lhs: ChatTarget, rhs: ChatTarget) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    private var currentUserId: UUID? { session.userID }

    private var awaitingMe: [OfferProposal] {
        guard let id = currentUserId else { return [] }
        return proposals.filter { $0.awaitingAction(by: id) }
    }

    private var awaitingOther: [OfferProposal] {
        guard let id = currentUserId else { return [] }
        return proposals.filter { $0.status == .pending && !$0.awaitingAction(by: id) }
    }

    private var closed: [OfferProposal] {
        proposals.filter { $0.status == .accepted }
    }

    var body: some View {
        Group {
            if state.isLoading {
                ScrollView {
                    LazyVStack(spacing: BrindooSpacing.sm) {
                        ForEach(0..<6, id: \.self) { _ in BrindooSkeletonCard() }
                    }
                    .padding(BrindooSpacing.md)
                }
                .disabled(true)
            } else if case .error(let message) = state {
                BrindooErrorState(message: message) {
                    Task { await loadData() }
                }
            } else if proposals.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: BrindooSpacing.lg) {
                        if !awaitingMe.isEmpty {
                            section(
                                title: "Aspettano una tua risposta",
                                icon: "exclamationmark.bubble.fill",
                                color: .brindooCoral,
                                proposals: awaitingMe
                            )
                        }
                        if !awaitingOther.isEmpty {
                            section(
                                title: "In attesa dell'altra parte",
                                icon: "clock",
                                color: .brindooWarning,
                                proposals: awaitingOther
                            )
                        }
                        if !closed.isEmpty {
                            section(
                                title: "Concluse",
                                icon: "checkmark.circle",
                                color: .brindooSuccess,
                                proposals: closed
                            )
                        }
                    }
                    .padding(BrindooSpacing.md)
                    .brindooReadableWidth()
                }
            }
        }
        .background(Color.brindooBackground)
        .navigationTitle("Trattative")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AgendaView()
                } label: {
                    Image(systemName: BrindooIcon.calendar)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.brindooCoral)
                }
                .accessibilityLabel("Agenda eventi")
            }
        }
        .task { await loadData() }
        .refreshable { await loadData() }
        .navigationDestination(item: $chatTarget) { target in
            ChatView(conversation: target.conversation, otherUser: target.other)
        }
        .sheet(item: $reviewTarget) { organizer in
            WriteReviewView(organizer: organizer, existingReview: nil) {
                Task { await loadData() }
            }
        }
    }

    @ViewBuilder
    private var emptyView: some View {
        BrindooEmptyState(
            icon: "arrow.left.arrow.right",
            title: "Nessuna trattativa",
            message: "Le proposte e controproposte sulle offerte appariranno qui",
            actionTitle: "Esplora la bacheca",
            action: { DeepLinkRouter.shared.selectedTab = 0 }
        )
    }

    @ViewBuilder
    private func section(
        title: String,
        icon: String,
        color: Color,
        proposals: [OfferProposal]
    ) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Text(title)
                    .font(BrindooFont.titleSmall)
                Spacer()
                Text("\(proposals.count)")
                    .font(BrindooFont.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(color.opacity(0.15))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
            }

            ForEach(proposals) { p in
                proposalRow(p)
            }
        }
    }

    /// Riga di ripiego quando il dettaglio dell'offerta non è arrivato
    /// (rete caduta a metà): la trattativa resta visibile e riprovabile,
    /// invece di sparire lasciando una sezione vuota che si contraddice
    /// con il numero mostrato nel titolo.
    @ViewBuilder
    private func unavailableRow(_ proposal: OfferProposal) -> some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: BrindooIcon.refresh)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.brindooTextSecondary)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dettagli non caricati")
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                Text("Tocca per riprovare")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            Spacer()
            Text(proposal.currentPriceDisplay)
                .font(BrindooFont.titleSmall)
                .foregroundStyle(Color.brindooCoral)
        }
        .padding(BrindooSpacing.md)
        .brindooSurfaceBackground()
        .contentShape(Rectangle())
        .onTapGesture { Task { await loadData() } }
    }

    @ViewBuilder
    private func proposalRow(_ proposal: OfferProposal) -> some View {
        if let offer = offerMap[proposal.offerId] {
            HStack(spacing: BrindooSpacing.xs) {
                NavigationLink {
                    OfferDetailView(offer: offer) {
                        Task { await loadData() }
                    }
                } label: {
                    row(proposal: proposal, offer: offer)
                }
                .buttonStyle(.plain)

                if proposal.status == .accepted {
                    if canReview(proposal) {
                        Button {
                            let otherId = (currentUserId == proposal.clientId) ? proposal.organizerId : proposal.clientId
                            reviewTarget = profileMap[otherId]
                        } label: {
                            Image(systemName: BrindooIcon.starFilled)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(BrindooGradient.pro)
                                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Lascia una recensione")
                    }

                    Button {
                        Task { await openChat(for: proposal) }
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.brindooCoral)
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Apri chat")

                    // Promemoria scritto dell'accordo, a portata di lista.
                    ShareLink(item: AgreementSummary.text(
                        offer: offer,
                        organizerName: profileMap[proposal.organizerId]?.displayName,
                        clientName: profileMap[proposal.clientId]?.displayName,
                        proposal: proposal
                    )) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.brindooCoral)
                            .frame(width: 44, height: 44)
                            .background(Color.brindooCoral.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    }

                    AgreementPDFShareButton(
                        offer: offer,
                        organizerName: profileMap[proposal.organizerId]?.displayName,
                        clientName: profileMap[proposal.clientId]?.displayName,
                        proposal: proposal,
                        compact: true
                    )
                    .accessibilityLabel("Condividi riepilogo accordo")
                }
            }
        } else {
            unavailableRow(proposal)
        }
    }

    /// Frase esplicita su chi deve muoversi adesso. Il pallino sulla scheda
    /// dice solo che qualcosa pende: qui si legge *cosa* e *a chi tocca*,
    /// anche per il passaggio dell'acconto (dichiara uno, conferma l'altro).
    private func waitingLabel(for proposal: OfferProposal) -> (text: String, isMine: Bool)? {
        guard let me = currentUserId else { return nil }
        if proposal.status == .pending {
            return proposal.awaitingAction(by: me)
                ? ("Tocca a te rispondere", true)
                : ("In attesa dell'altra parte", false)
        }
        if proposal.status == .accepted, proposal.isDepositAwaitingConfirmation {
            return proposal.canConfirmDeposit(as: me)
                ? ("Tocca a te confermare l'acconto", true)
                : ("In attesa che confermino l'acconto", false)
        }
        return nil
    }

    /// Il cliente può recensire quando l'evento è svolto o la data è passata.
    private func canReview(_ proposal: OfferProposal) -> Bool {
        guard currentUserId == proposal.clientId else { return false }
        return proposal.effectiveBooking == .completed || proposal.isEventPast
    }

    private func openChat(for proposal: OfferProposal) async {
        guard let me = currentUserId else { return }
        let otherId = (me == proposal.clientId) ? proposal.organizerId : proposal.clientId
        guard let other = profileMap[otherId] else { return }
        do {
            let conv: Conversation
            if me == proposal.clientId {
                conv = try await ConversationService.shared
                    .findOrCreateConversationAsClient(organizerId: proposal.organizerId)
            } else {
                conv = try await ConversationService.shared
                    .findOrCreateConversationAsOrganizer(clientId: proposal.clientId)
            }
            chatTarget = ChatTarget(id: conv.id, conversation: conv, other: other)
        } catch {
            BrindooLog.error("\(error)")
        }
    }

    @ViewBuilder
    private func row(proposal: OfferProposal, offer: ServiceOffer) -> some View {
        let otherId = (currentUserId == proposal.clientId)
            ? proposal.organizerId
            : proposal.clientId
        let other = profileMap[otherId]

        HStack(spacing: BrindooSpacing.sm) {
            AvatarView(url: other?.avatarUrl, name: other?.fullName, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(offer.title)
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                    .lineLimit(1)
                Text(other?.fullName ?? "Utente")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                // Il professionista vede com'è andata in passato con questo cliente.
                if currentUserId == proposal.organizerId,
                   let badge = clientTrust[proposal.clientId]?.badge {
                    HStack(spacing: 3) {
                        Image(systemName: badge.icon)
                            .font(.system(size: 10))
                        Text(badge.label)
                            .font(BrindooFont.caption.weight(.medium))
                    }
                    .foregroundStyle(badge.isPositive ? Color.brindooSuccess : Color.brindooWarning)
                    .accessibilityLabel(badge.label)
                }
                if let eventDate = proposal.eventDateDisplay {
                    HStack(spacing: 3) {
                        Image(systemName: BrindooIcon.calendar)
                            .font(.system(size: 10))
                        Text(eventDate)
                            .font(BrindooFont.caption.weight(.medium))
                    }
                    .foregroundStyle(Color.brindooCoral)
                }
                if proposal.status == .accepted, proposal.bookingStatus != nil {
                    HStack(spacing: 3) {
                        Image(systemName: proposal.effectiveBooking.iconName)
                            .font(.system(size: 10))
                        Text(proposal.effectiveBooking.displayName)
                            .font(BrindooFont.caption.weight(.semibold))
                    }
                    .foregroundStyle(proposal.effectiveBooking == .cancelled ? Color.brindooError : Color.brindooSuccess)
                }
                if let waiting = waitingLabel(for: proposal) {
                    HStack(spacing: 3) {
                        Image(systemName: waiting.isMine ? "exclamationmark.circle.fill" : "clock")
                            .font(.system(size: 10))
                        Text(waiting.text)
                            .font(BrindooFont.caption.weight(.semibold))
                            .lineLimit(2)
                    }
                    .foregroundStyle(waiting.isMine ? Color.brindooCoral : Color.brindooTextSecondary)
                    .accessibilityLabel(waiting.text)
                }
                Text(proposal.updatedAtDisplay)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            Spacer(minLength: BrindooSpacing.xs)
            VStack(alignment: .trailing, spacing: 2) {
                // Il prezzo è il dato che si cerca per primo: sta sopra
                // agli altri anche per dimensione.
                Text(proposal.currentPriceDisplay)
                    .font(BrindooFont.titleSmall)
                    .foregroundStyle(Color.brindooCoral)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: BrindooIcon.forward)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
        .padding(BrindooSpacing.md)
        .brindooSurfaceBackground()
    }

    // MARK: - Loading

    private func loadData() async {
        // Se una lista è già a schermo, l'aggiornamento avviene in silenzio.
        if state.value == nil { state = .loading }
        do {
            let fetched = try await OfferProposalService.shared.fetchMyOngoingProposals()
            await loadRelated(for: fetched)
            state = fetched.isEmpty ? .empty : .loaded(fetched)
        } catch {
            BrindooLog.error("Errore caricamento trattative: \(error)")
            if state.value == nil {
                state = .error(BrindooText.loadError("le trattative"))
            } else {
                toastCenter.show(BrindooToast(BrindooText.updateError("le trattative"), message: BrindooText.retryHint, style: .error))
            }
        }
    }

    private func loadRelated(for proposals: [OfferProposal]) async {
        // Due sole richieste (offerte + profili), non una per trattativa.
        let offerIds = Set(proposals.map { $0.offerId }).filter { offerMap[$0] == nil }
        var profileIds = Set(proposals.flatMap { [$0.clientId, $0.organizerId] })
        if let me = currentUserId { profileIds.remove(me) }
        let missingProfiles = profileIds.filter { profileMap[$0] == nil }

        // Se questi due passaggi falliscono la lista resta a metà: va detto,
        // altrimenti sembra che le trattative non ci siano più.
        var partial = false
        do {
            let offers = try await ServiceOfferService.shared.fetchOffers(ids: Array(offerIds))
            for o in offers { offerMap[o.id] = o }
        } catch {
            partial = true
            BrindooLog.error("Offerte delle trattative non caricate: \(error)")
        }
        do {
            let profiles = try await ProfileService.shared.fetchProfiles(ids: Array(missingProfiles))
            for p in profiles { profileMap[p.id] = p }
        } catch {
            partial = true
            BrindooLog.error("Profili delle trattative non caricati: \(error)")
        }
        if partial {
            toastCenter.show(BrindooToast(
                "Trattative caricate solo in parte",
                message: BrindooText.retryHint,
                style: .error
            ))
        }

        // Affidabilità dei clienti: serve solo a chi sta dall'altra parte.
        if let me = currentUserId {
            let clientIds = proposals.filter { $0.organizerId == me }.map(\.clientId)
            if !clientIds.isEmpty,
               let trust = try? await ClientTrustService.shared.fetchTrust(clientIds: Array(Set(clientIds))) {
                clientTrust.merge(trust) { _, new in new }
            }
        }
    }
}
