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

    private var proposals: [OfferProposal] { state.value ?? [] }

    private static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

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
                  let date = Self.dayParser.date(from: dateString) else { return nil }
            return Entry(proposal: p, date: date)
        }
    }

    private var upcoming: [Entry] {
        let today = Calendar.current.startOfDay(for: Date())
        return entries.filter { $0.date >= today }.sorted { $0.date < $1.date }
    }

    private var past: [Entry] {
        let today = Calendar.current.startOfDay(for: Date())
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
        .sheet(item: $checklistEntry) { entry in
            EventChecklistView(
                proposalId: entry.proposal.id,
                eventDate: entry.date,
                offerTitle: offerMap[entry.proposal.offerId]?.title ?? "Evento"
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
                Image(systemName: "sparkles")
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

                Image(systemName: "chevron.right")
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
                Task { await toggleDeposit(entry) }
            } label: {
                Label(
                    proposal.isDepositPaid ? "Acconto: segna come non versato" : "Segna acconto versato",
                    systemImage: "eurosign.circle"
                )
            }
            if entry.date >= Calendar.current.startOfDay(for: Date()) {
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
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .background(Color.brindooCoral)
                Text(entry.date.formatted(.dateTime.day()))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
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
                        Image(systemName: "eurosign.circle.fill")
                            .font(.system(size: 10))
                        Text("Acconto versato")
                            .font(BrindooFont.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.brindooSuccess)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(proposal.currentPriceDisplay)
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brindooCoral)

                // "Aggiungi al calendario iPhone" solo per gli eventi futuri.
                if entry.date >= Calendar.current.startOfDay(for: Date()) {
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
                            Task { await toggleDeposit(entry) }
                        } label: {
                            Label(
                                entry.proposal.isDepositPaid ? "Acconto: segna come non versato" : "Segna acconto versato",
                                systemImage: "eurosign.circle"
                            )
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
                    Image(systemName: "chevron.right")
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
    private func toggleDeposit(_ entry: Entry) async {
        do {
            try await OfferProposalService.shared.setDepositPaid(
                proposalId: entry.proposal.id,
                paid: !entry.proposal.isDepositPaid
            )
            BrindooHaptics.notify(.success)
            await loadData()
        } catch {
            toastCenter.show(BrindooToast("Impossibile aggiornare l'acconto", style: .error))
        }
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
                state = .error("Impossibile caricare l'agenda")
            } else {
                toastCenter.show(BrindooToast("Impossibile aggiornare l'agenda", message: "Controlla la connessione e riprova.", style: .error))
            }
        }
    }

    private func loadRelated() async {
        // Due sole richieste (offerte + profili), non una per elemento.
        let offerIds = Set(entries.map { $0.proposal.offerId }).filter { offerMap[$0] == nil }
        var profileIds = Set(entries.flatMap { [$0.proposal.clientId, $0.proposal.organizerId] })
        if let me = session.userID { profileIds.remove(me) }
        let missingProfiles = profileIds.filter { profileMap[$0] == nil }

        if let offers = try? await ServiceOfferService.shared.fetchOffers(ids: Array(offerIds)) {
            for o in offers { offerMap[o.id] = o }
        }
        if let profiles = try? await ProfileService.shared.fetchProfiles(ids: Array(missingProfiles)) {
            for p in profiles { profileMap[p.id] = p }
        }
    }
}
