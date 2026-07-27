//
//  AgendaView.swift
//  Brindoo
//
//  Agenda degli appuntamenti: tutti gli eventi delle trattative concluse,
//  con data, in ordine cronologico. "In arrivo" prima, "Passati" sotto.
//

import SwiftUI

struct AgendaView: View {

    @Environment(SessionStore.self) private var session
    @EnvironmentObject private var toastCenter: BrindooToastCenter

    @State private var state: LoadState<[OfferProposal]> = .loading
    @State private var offerMap: [UUID: ServiceOffer] = [:]
    @State private var profileMap: [UUID: Profile] = [:]
    @State private var checklistEntry: Entry?
    /// Trattativa di cui stiamo gestendo acconto e modo di pagamento.
    @State private var depositProposal: OfferProposal?
    /// Eventi passati per cui il professionista non ha ancora detto
    /// com'è andata col cliente.
    @State private var pendingFeedbackIds: Set<UUID> = []
    @State private var sendingFeedback: UUID?

    private var proposals: [OfferProposal] { state.value ?? [] }

    /// Riga dell'agenda: trattativa conclusa con una data evento valida.
    private struct Entry: Identifiable {
        let proposal: OfferProposal
        let date: Date
        var id: UUID { proposal.id }
    }

    private var entries: [Entry] {
        proposals.compactMap { p in
            guard p.status == .accepted,
                  p.effectiveBooking != .cancelled,
                  let dateString = p.eventDate,
                  let date = BrindooFormat.day(from: dateString) else { return nil }
            return Entry(proposal: p, date: date)
        }
    }

    private var upcoming: [Entry] {
        let today = BrindooFormat.startOfDay()
        return entries.filter { $0.date >= today }.sorted { $0.date < $1.date }
    }

    private var past: [Entry] {
        let today = BrindooFormat.startOfDay()
        return entries.filter { $0.date < today }.sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if state.isLoading {
                ScrollView {
                    LazyVStack(spacing: BrindooSpacing.sm) {
                        ForEach(0..<5, id: \.self) { _ in BrindooSkeletonCard() }
                    }
                    .padding(BrindooSpacing.md)
                }
                .disabled(true)
            } else if case .error(let message) = state {
                BrindooErrorState(message: message) {
                    Task { await loadData() }
                }
            } else if entries.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: BrindooSpacing.lg) {
                        if !upcoming.isEmpty {
                            section(title: "In arrivo", icon: "calendar.badge.clock",
                                    color: .brindooCoral, entries: upcoming)

                            Text("Tocca ⋯ su un evento per acconto e checklist.")
                                .font(BrindooFont.caption)
                                .foregroundStyle(Color.brindooTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if session.currentProfile?.role == .client {
                                completeEventCard
                            }
                        }
                        if let entry = feedbackEntry {
                            ClientFeedbackPrompt(
                                clientName: profileMap[entry.proposal.clientId]?.displayName ?? "il cliente",
                                isSending: sendingFeedback == entry.proposal.id
                            ) { outcome in
                                Task { await sendFeedback(entry, outcome: outcome) }
                            } onSkip: {
                                pendingFeedbackIds.remove(entry.proposal.id)
                            }
                        }
                        if !past.isEmpty {
                            section(title: "Passati", icon: "checkmark.circle",
                                    color: .brindooTextSecondary, entries: past)
                        }
                    }
                    .padding(BrindooSpacing.md)
                    .brindooReadableWidth()
                }
            }
        }
        .background(Color.brindooBackground)
        .navigationTitle("Agenda eventi")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $depositProposal) { proposal in
            DepositSheet(proposal: proposal) { await loadData() }
        }
        .sheet(item: $checklistEntry) { entry in
            EventChecklistView(
                proposalId: entry.proposal.id,
                eventDate: entry.date,
                offerTitle: offerMap[entry.proposal.offerId]?.title ?? "Evento",
                depositSettled: entry.proposal.isDepositPaid
            )
        }
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    /// Invito a completare l'evento con altri servizi per la stessa data.
    @ViewBuilder
    private var completeEventCard: some View {
        NavigationLink {
            GuidedQuoteView(prefilledDate: upcoming.first?.date)
        } label: {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: BrindooIcon.explore)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brindooCoral)
                    .frame(width: 36, height: 36)
                    .background(Color.brindooCoral.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Completa il tuo evento")
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                    Text("Ti serve altro per la stessa data? Musica, foto, catering…")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }

                Spacer()

                Image(systemName: BrindooIcon.forward)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: BrindooRadius.md)
                    .strokeBorder(Color.brindooCoral.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var emptyView: some View {
        BrindooEmptyState(
            icon: "calendar",
            title: "Nessun evento in agenda",
            message: "Quando una trattativa si conclude con una data, l'evento compare qui."
        )
    }

    @ViewBuilder
    private func section(title: String, icon: String, color: Color, entries: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Text(title)
                    .font(BrindooFont.titleSmall)
                Spacer()
                Text("\(entries.count)")
                    .font(BrindooFont.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(color.opacity(0.15))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
            }

            ForEach(entries) { entry in
                row(entry)
            }
        }
    }

    @ViewBuilder
    private func row(_ entry: Entry) -> some View {
        let proposal = entry.proposal
        let otherId = (session.userID == proposal.clientId) ? proposal.organizerId : proposal.clientId
        let other = profileMap[otherId]
        let offer = offerMap[proposal.offerId]

        Group {
            if let offer {
                NavigationLink {
                    OfferDetailView(offer: offer) {
                        Task { await loadData() }
                    }
                } label: {
                    rowContent(entry, offer: offer, other: other)
                }
                .buttonStyle(.plain)
            } else {
                rowContent(entry, offer: nil, other: other)
            }
        }
        .contextMenu {
            Button {
                depositProposal = proposal
            } label: {
                Label(depositLabel(proposal), systemImage: "eurosign.circle")
            }
            if entry.date >= BrindooFormat.startOfDay() {
                Button {
                    checklistEntry = entry
                } label: {
                    Label("Checklist evento", systemImage: "checklist")
                }
            }
        }
    }

    @ViewBuilder
    private func rowContent(_ entry: Entry, offer: ServiceOffer?, other: Profile?) -> some View {
        let proposal = entry.proposal

        HStack(spacing: BrindooSpacing.sm) {
            // Riquadro data stile calendario
            VStack(spacing: 0) {
                Text(entry.date.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "it_IT"))))
                    .font(BrindooFont.scaled(11, weight: .bold, relativeTo: .caption1))
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .background(Color.brindooCoral)
                Text(entry.date.formatted(.dateTime.day()))
                    .font(BrindooFont.scaled(22, weight: .bold, rounded: true, relativeTo: .title2))
                    .foregroundStyle(Color.brindooTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .frame(width: 52)
            .background(Color.brindooBackground)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: BrindooRadius.sm)
                    .strokeBorder(Color.brindooBorder, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(offer?.title ?? "Evento")
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brindooTextPrimary)
                    .lineLimit(1)
                Text("con \(other?.fullName ?? "utente")")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                HStack(spacing: 3) {
                    Image(systemName: proposal.effectiveBooking.iconName)
                        .font(.system(size: 10))
                    Text(proposal.effectiveBooking.displayName)
                        .font(BrindooFont.caption.weight(.semibold))
                }
                .foregroundStyle(proposal.effectiveBooking == .completed ? Color.brindooSuccess : Color.brindooCoral)

                if proposal.isDepositPaid {
                    HStack(spacing: 3) {
                        Image(systemName: BrindooIcon.money)
                            .font(.system(size: 10))
                        Text("Acconto versato\(proposal.depositAmountDisplay.map { " · \($0)" } ?? "")")
                            .font(BrindooFont.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.brindooSuccess)
                } else if proposal.isDepositAwaitingConfirmation {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 10))
                        Text(proposal.canConfirmDeposit(as: session.userID ?? UUID())
                             ? "Acconto da confermare"
                             : "Acconto in attesa di conferma")
                            .font(BrindooFont.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.brindooWarning)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(proposal.currentPriceDisplay)
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brindooCoral)

                // "Aggiungi al calendario iPhone" solo per gli eventi futuri.
                if entry.date >= BrindooFormat.startOfDay() {
                    Button {
                        Task { await addToCalendar(entry, offerTitle: offer?.title) }
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.brindooCoral)
                            .frame(width: 32, height: 32)
                            .background(Color.brindooCoral.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Aggiungi al calendario")

                    // Stesse azioni del tocco prolungato, ma visibili:
                    // acconto e checklist a portata di tap.
                    Menu {
                        Button {
                            depositProposal = entry.proposal
                        } label: {
                            Label(depositLabel(entry.proposal), systemImage: "eurosign.circle")
                        }
                        Button {
                            checklistEntry = entry
                        } label: {
                            Label("Checklist evento", systemImage: "checklist")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.brindooTextSecondary)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Altre azioni")
                } else {
                    Image(systemName: BrindooIcon.forward)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.brindooTextSecondary)
                }
            }
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    /// Mette l'evento nel calendario dell'iPhone, con avviso di esito.
    private func addToCalendar(_ entry: Entry, offerTitle: String?) async {
        guard let day = entry.proposal.eventDate else { return }
        do {
            try await CalendarService.addAllDayEvent(
                title: "🎉 \(offerTitle ?? "Evento") — Brindoo",
                dayString: day,
                notes: "Evento concordato su Brindoo per \(entry.proposal.currentPriceDisplay)."
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

    /// Registra o toglie l'acconto versato sull'evento.
    /// Cosa scrivere sulla voce di menù, in base a dove sta l'acconto.
    private func depositLabel(_ proposal: OfferProposal) -> String {
        if proposal.isDepositPaid { return "Acconto versato · vedi dettagli" }
        if proposal.canConfirmDeposit(as: session.userID ?? UUID()) { return "Conferma l'acconto ricevuto" }
        if proposal.isDepositAwaitingConfirmation { return "Acconto in attesa di conferma" }
        return "Acconto e pagamento"
    }

    // MARK: - Loading

    private func loadData() async {
        // Se una lista è già a schermo, l'aggiornamento avviene in silenzio.
        if state.value == nil { state = .loading }
        do {
            let fetched = try await OfferProposalService.shared.fetchMyOngoingProposals()
            state = fetched.isEmpty ? .empty : .loaded(fetched)
            await loadRelated()
        } catch {
            BrindooLog.error("Errore caricamento agenda: \(error)")
            if state.value == nil {
                state = .error(BrindooText.loadError("l'agenda"))
            } else {
                toastCenter.show(BrindooToast("Impossibile aggiornare l'agenda", message: BrindooText.retryHint, style: .error))
            }
        }
    }

    private func loadRelated() async {
        // Due sole richieste (offerte + profili), non una per elemento.
        let offerIds = Set(entries.map { $0.proposal.offerId }).filter { offerMap[$0] == nil }
        var profileIds = Set(entries.flatMap { [$0.proposal.clientId, $0.proposal.organizerId] })
        if let me = session.userID { profileIds.remove(me) }
        let missingProfiles = profileIds.filter { profileMap[$0] == nil }

        // Senza questi dati gli eventi restano in agenda ma con titoli e nomi
        // generici: meglio dirlo che far credere che l'evento sia cambiato.
        var partial = false
        do {
            let offers = try await ServiceOfferService.shared.fetchOffers(ids: Array(offerIds))
            for o in offers { offerMap[o.id] = o }
        } catch {
            partial = true
            BrindooLog.error("Offerte dell'agenda non caricate: \(error)")
        }
        do {
            let profiles = try await ProfileService.shared.fetchProfiles(ids: Array(missingProfiles))
            for p in profiles { profileMap[p.id] = p }
        } catch {
            partial = true
            BrindooLog.error("Profili dell'agenda non caricati: \(error)")
        }
        if partial {
            toastCenter.show(BrindooToast(
                "Agenda caricata solo in parte",
                message: BrindooText.retryHint,
                style: .error
            ))
        }

        // Solo per il professionista: eventi passati ancora senza esito.
        if session.currentProfile?.role == .organizer {
            pendingFeedbackIds = await ClientTrustService.shared
                .pendingFeedbackProposalIds(among: proposals)
        }
    }

    /// Primo evento passato di cui chiedere l'esito (uno alla volta).
    private var feedbackEntry: Entry? {
        past.first { pendingFeedbackIds.contains($0.proposal.id) }
    }

    private func sendFeedback(_ entry: Entry, outcome: ClientOutcome) async {
        sendingFeedback = entry.proposal.id
        defer { sendingFeedback = nil }
        do {
            try await ClientTrustService.shared.submit(
                proposalId: entry.proposal.id,
                clientId: entry.proposal.clientId,
                outcome: outcome
            )
            pendingFeedbackIds.remove(entry.proposal.id)
            BrindooHaptics.notify(.success)
            toastCenter.show(BrindooToast("Grazie, aiuta gli altri professionisti", style: .success))
        } catch {
            BrindooLog.error("Esito cliente: \(error)")
            toastCenter.show(BrindooToast("Non è stato possibile salvare l'esito", style: .error))
        }
    }
}
