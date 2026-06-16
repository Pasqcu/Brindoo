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

struct OfferDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    let offer: ServiceOffer

    @State private var categories: [ServiceCategory] = []
    @State private var organizerProfile: Profile?
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

    // Recensione post-evento
    @State private var showWriteReview: Bool = false

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                if let imageUrl = offer.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .empty:
                            BrindooSkeleton(cornerRadius: BrindooRadius.md)
                        default:
                            Color.brindooSurface
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                }

                headerSection

                Divider()

                if !categories.isEmpty {
                    categoriesSection
                }

                infoSection

                descriptionSection

                if let error = actionError {
                    errorBanner(error)
                }

                if canClientInteract {
                    Divider()
                    clientNegotiationSection
                }

                if isOwnOffer {
                    Divider()
                    ownerControls
                    receivedProposalsSection
                }
            }
            .padding(BrindooSpacing.md)
            .brindooReadableWidth()
        }
        .background(Color.brindooBackground)
        .navigationTitle("Offerta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: URL(string: "https://brindoo.app/o/\(offer.id.uuidString)")!) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.brindooCoral)
                }
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

    // MARK: - Header / info / descrizione

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            HStack {
                Text(offer.title)
                    .font(BrindooFont.titleLarge)
                Spacer()
                statusBadge
            }

            if let profile = organizerProfile {
                NavigationLink {
                    OrganizerDetailView(organizer: profile)
                } label: {
                    HStack(spacing: BrindooSpacing.xs) {
                        AvatarView(url: profile.avatarUrl, name: profile.fullName, size: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 4) {
                                Text(profile.fullName ?? "Organizzatore")
                                    .font(BrindooFont.bodyMedium.weight(.medium))
                                if profile.isPro {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.brindooCoral)
                                }
                            }
                            Text("Vedi profilo")
                                .font(BrindooFont.caption)
                                .foregroundStyle(Color.brindooCoral)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (color, text): (Color, String) = {
            switch currentStatus {
            case .active: return (.brindooSuccess, "Attiva")
            case .paused: return (.brindooTextSecondary, "In pausa")
            }
        }()
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Categorie").font(BrindooFont.titleSmall)
            FlowLayoutView(spacing: BrindooSpacing.xs) {
                ForEach(categories) { cat in
                    HStack(spacing: 4) {
                        Image(systemName: cat.icon).font(.system(size: 12))
                        Text(cat.name).font(BrindooFont.bodySmall.weight(.medium))
                    }
                    .padding(.horizontal, BrindooSpacing.sm)
                    .padding(.vertical, BrindooSpacing.xs)
                    .foregroundStyle(Color.brindooCoral)
                    .background(Color.brindooCoral.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private var infoSection: some View {
        VStack(spacing: BrindooSpacing.xs) {
            infoRow(icon: "mappin.and.ellipse", title: "Zona", value: offer.coverageArea)
            infoRow(icon: "eurosign.circle", title: "Prezzo richiesto", value: offer.priceDisplay)
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    @ViewBuilder
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.brindooCoral)
                Text(title)
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            Spacer()
            Text(value)
                .font(BrindooFont.bodyMedium.weight(.medium))
        }
    }

    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Descrizione")
                .font(BrindooFont.titleSmall)
            Text(offer.description)
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Cliente: 3 azioni iniziali oppure stato trattativa

    @ViewBuilder
    private var clientNegotiationSection: some View {
        if let proposal = myProposal {
            existingProposalCard(proposal)
        } else {
            initialClientActions
        }
    }

    @ViewBuilder
    private var initialClientActions: some View {
        VStack(spacing: BrindooSpacing.sm) {
            Text("Cosa vuoi fare?")
                .font(BrindooFont.titleSmall)
                .frame(maxWidth: .infinity, alignment: .leading)

            BrindooButton(
                "Accetta a \(offer.priceDisplay)",
                style: .primary,
                size: .large,
                icon: "checkmark"
            ) {
                Task { await acceptAtOrganizerPrice() }
            }

            BrindooButton(
                "Fai una proposta",
                style: .secondary,
                size: .medium,
                icon: "arrow.left.arrow.right"
            ) {
                showNegotiateSheet = .openAsClient(offer: offer)
            }

            Button {
                Task { await dismissOffer() }
            } label: {
                Label("Nascondi questa offerta", systemImage: "eye.slash")
                    .font(BrindooFont.bodySmall.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BrindooSpacing.sm)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func existingProposalCard(_ proposal: OfferProposal) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack {
                Text("Trattativa in corso")
                    .font(BrindooFont.titleSmall)
                Spacer()
                proposalStatusPill(proposal.status)
            }

            // Mostra "ultima controproposta" — chi ha proposto cosa.
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: proposal.lastProposer == .organizer ? "person.badge.shield.checkmark" : "person.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.brindooCoral)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(proposal.lastProposer == .organizer ? "Controproposta organizzatore" : "La tua proposta")
                        .font(BrindooFont.bodySmall.weight(.semibold))
                    Text(proposal.currentPriceDisplay)
                        .font(BrindooFont.titleMedium)
                        .foregroundStyle(Color.brindooCoral)
                }
                Spacer()
                Text(proposal.updatedAtDisplay)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }

            if let eventDate = proposal.eventDateDisplay {
                eventDateRow(eventDate)
            }

            if let lastMessage = proposal.lastMessage, !lastMessage.isEmpty {
                Text("\"\(lastMessage)\"")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            clientProposalActions(proposal)
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    @ViewBuilder
    private func clientProposalActions(_ proposal: OfferProposal) -> some View {
        if proposal.status == .accepted, let org = organizerProfile {
            VStack(spacing: BrindooSpacing.sm) {
                bookingStatusRow(proposal)

                BrindooButton("Apri chat", style: .primary, size: .medium, icon: "bubble.left.and.bubble.right.fill") {
                    Task { await openChat(with: org) }
                }

                if proposal.effectiveBooking == .completed {
                    BrindooButton("Lascia una recensione", style: .secondary, size: .medium, icon: "star.fill") {
                        showWriteReview = true
                    }
                }

                bookingActionButtons(proposal)
            }
            .sheet(isPresented: $showWriteReview) {
                WriteReviewView(organizer: org, existingReview: nil) {
                    Task { await loadData() }
                }
            }
        } else if proposal.status == .pending {
            if proposal.lastProposer == .organizer {
                // Palla al cliente: può accettare, controproporre o rifiutare la controproposta.
                VStack(spacing: BrindooSpacing.sm) {
                    HStack(spacing: BrindooSpacing.sm) {
                        Button { Task { await rejectProposal(proposal) } } label: {
                            Label("Rifiuta", systemImage: "xmark")
                                .font(BrindooFont.bodySmall.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(Color.brindooError)
                                .background(Color.brindooError.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                        }
                        .buttonStyle(.plain)

                        Button { Task { await acceptProposal(proposal) } } label: {
                            Label("Accetta", systemImage: "checkmark")
                                .font(BrindooFont.bodySmall.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(.white)
                                .background(Color.brindooSuccess)
                                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                        }
                        .buttonStyle(.plain)
                    }

                    BrindooButton(
                        "Controproponi",
                        style: .secondary,
                        size: .medium,
                        icon: "arrow.left.arrow.right"
                    ) {
                        showNegotiateSheet = .counter(proposal: proposal, role: .client, offer: offer)
                    }
                }
            } else {
                // L'utente sta aspettando una risposta dall'organizzatore.
                Text("In attesa di risposta dall'organizzatore.")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)

                BrindooButton(
                    "Ritira proposta",
                    style: .tertiary,
                    size: .medium
                ) {
                    Task { await withdrawProposal(proposal) }
                }
            }
        }
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

    @ViewBuilder
    private var receivedProposalsSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack {
                Text("Proposte ricevute")
                    .font(BrindooFont.titleSmall)
                Spacer()
                if !receivedProposals.isEmpty {
                    Text("\(receivedProposals.count)")
                        .font(BrindooFont.caption.weight(.semibold))
                        .padding(.horizontal, BrindooSpacing.xs)
                        .padding(.vertical, 3)
                        .background(Color.brindooCoral)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            if receivedProposals.isEmpty {
                Text("Nessuna proposta ancora. Quando un cliente farà una proposta apparirà qui.")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(BrindooSpacing.md)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            } else {
                ForEach(receivedProposals) { proposal in
                    proposalCardForOrganizer(proposal)
                }
            }
        }
    }

    @ViewBuilder
    private func proposalCardForOrganizer(_ proposal: OfferProposal) -> some View {
        let client = clientProfilesMap[proposal.clientId]
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack(spacing: BrindooSpacing.sm) {
                AvatarView(url: client?.avatarUrl, name: client?.fullName, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(client?.fullName ?? "Cliente")
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                    Text(proposal.updatedAtDisplay)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                Spacer()
                proposalStatusPill(proposal.status)
            }

            HStack(spacing: BrindooSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(proposal.lastProposer == .client ? "Proposta del cliente" : "Tua controproposta")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                    Text(proposal.currentPriceDisplay)
                        .font(BrindooFont.titleSmall)
                        .foregroundStyle(Color.brindooCoral)
                }
                Spacer()
            }

            if let eventDate = proposal.eventDateDisplay {
                eventDateRow(eventDate)
            }

            if let lastMessage = proposal.lastMessage, !lastMessage.isEmpty {
                Text("\"\(lastMessage)\"")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            organizerProposalActions(proposal, client: client)
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    @ViewBuilder
    private func organizerProposalActions(_ proposal: OfferProposal, client: Profile?) -> some View {
        if proposal.status == .accepted, let client {
            VStack(spacing: BrindooSpacing.sm) {
                bookingStatusRow(proposal)
                BrindooButton("Apri chat", style: .primary, size: .medium, icon: "bubble.left.and.bubble.right.fill") {
                    Task { await openChat(with: client) }
                }
                bookingActionButtons(proposal)
            }
        } else if proposal.status == .pending, proposal.lastProposer == .client {
            VStack(spacing: BrindooSpacing.sm) {
                HStack(spacing: BrindooSpacing.sm) {
                    Button { Task { await rejectProposal(proposal) } } label: {
                        Label("Rifiuta", systemImage: "xmark")
                            .font(BrindooFont.bodySmall.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(Color.brindooError)
                            .background(Color.brindooError.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                    .buttonStyle(.plain)

                    Button { Task { await acceptProposal(proposal) } } label: {
                        Label("Accetta", systemImage: "checkmark")
                            .font(BrindooFont.bodySmall.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(.white)
                            .background(Color.brindooSuccess)
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                    .buttonStyle(.plain)
                }
                BrindooButton(
                    "Controproponi",
                    style: .secondary,
                    size: .medium,
                    icon: "arrow.left.arrow.right"
                ) {
                    showNegotiateSheet = .counter(proposal: proposal, role: .organizer, offer: offer)
                }
            }
        } else if proposal.status == .pending && proposal.lastProposer == .organizer {
            Text("In attesa di risposta dal cliente.")
                .font(BrindooFont.bodySmall)
                .foregroundStyle(Color.brindooTextSecondary)
        }
    }

    @ViewBuilder
    private func bookingStatusRow(_ proposal: OfferProposal) -> some View {
        let booking = proposal.effectiveBooking
        let color: Color = {
            switch booking {
            case .confirmed: return .brindooSuccess
            case .completed: return .brindooCoral
            case .cancelled: return .brindooError
            }
        }()
        HStack(spacing: BrindooSpacing.xs) {
            Image(systemName: booking.iconName)
                .font(.system(size: 13, weight: .semibold))
            Text("Appuntamento: \(booking.displayName)")
                .font(BrindooFont.bodySmall.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(color)
        .padding(.vertical, BrindooSpacing.xxs)
        .padding(.horizontal, BrindooSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
    }

    @ViewBuilder
    private func bookingActionButtons(_ proposal: OfferProposal) -> some View {
        if proposal.effectiveBooking == .confirmed {
            HStack(spacing: BrindooSpacing.sm) {
                Button { Task { await markBooking(proposal, .completed) } } label: {
                    Label("Segna svolto", systemImage: "checkmark.seal")
                        .font(BrindooFont.bodySmall.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(Color.brindooSuccess)
                        .background(Color.brindooSuccess.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                }
                .buttonStyle(.plain)

                Button { Task { await markBooking(proposal, .cancelled) } } label: {
                    Label("Annulla", systemImage: "calendar.badge.minus")
                        .font(BrindooFont.bodySmall.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(Color.brindooError)
                        .background(Color.brindooError.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func eventDateRow(_ dateText: String) -> some View {
        HStack(spacing: BrindooSpacing.xs) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .medium))
            Text("Data evento: \(dateText)")
                .font(BrindooFont.bodySmall.weight(.medium))
            Spacer()
        }
        .foregroundStyle(Color.brindooCoral)
        .padding(.vertical, BrindooSpacing.xxs)
        .padding(.horizontal, BrindooSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooCoral.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
    }

    @ViewBuilder
    private func proposalStatusPill(_ status: OfferProposalStatus) -> some View {
        let color: Color = {
            switch status {
            case .pending:   return .brindooWarning
            case .accepted:  return .brindooSuccess
            case .rejected:  return .brindooError
            case .withdrawn: return .brindooTextSecondary
            }
        }()
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
                .font(.system(size: 9))
            Text(status.displayName)
                .font(BrindooFont.caption.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func loadData() async {
        do {
            categories = try await ServiceOfferService.shared.fetchOfferCategories(offerId: offer.id)
        } catch { print("❌ \(error)") }

        do {
            organizerProfile = try await ProfileService.shared.fetchProfile(userID: offer.organizerId)
        } catch { print("❌ \(error)") }

        // Cliente: carica la sua trattativa attiva + stato preferito + traccia view.
        if canClientInteract {
            do {
                myProposal = try await OfferProposalService.shared.fetchMyActiveProposal(forOffer: offer.id)
                if let p = myProposal {
                    myProposalLastRound = try await OfferProposalService.shared.fetchLastRound(proposalId: p.id)
                }
            } catch { print("❌ \(error)") }

            isFavorite = (try? await OfferFavoriteService.shared.isFavorite(offerId: offer.id)) ?? false

            // Traccia view (best-effort, ignora errori).
            await AnalyticsService.shared.trackOfferView(offerId: offer.id)
        }

        // Organizzatore proprietario: carica le proposte ricevute
        if isOwnOffer {
            do {
                receivedProposals = try await OfferProposalService.shared.fetchProposals(forOffer: offer.id)
                await loadClientsAndRounds(for: receivedProposals)
            } catch { print("❌ \(error)") }
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
            print("❌ \(error)")
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

    private func acceptAtOrganizerPrice() async {
        actionError = nil
        do {
            _ = try await OfferProposalService.shared.openProposal(
                offer: offer,
                price: offer.price,
                message: nil
            )
            await loadData()
        } catch {
            actionError = "Impossibile inviare la proposta."
            print("❌ \(error)")
        }
    }

    private func acceptProposal(_ proposal: OfferProposal) async {
        actionError = nil
        do {
            let conv = try await OfferProposalService.shared.accept(proposal: proposal)
            BrindooHaptics.notify(.success)
            await loadData()
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
            print("❌ \(error)")
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
        } catch {
            actionError = "Impossibile aggiornare l'appuntamento."
            print("❌ \(error)")
        }
    }

    private func rejectProposal(_ proposal: OfferProposal) async {
        actionError = nil
        do {
            try await OfferProposalService.shared.reject(proposal: proposal)
            await loadData()
        } catch {
            actionError = "Impossibile rifiutare."
            print("❌ \(error)")
        }
    }

    private func withdrawProposal(_ proposal: OfferProposal) async {
        actionError = nil
        do {
            try await OfferProposalService.shared.withdraw(proposal: proposal)
            await loadData()
        } catch {
            actionError = "Impossibile ritirare."
            print("❌ \(error)")
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
            print("❌ \(error)")
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
        } catch { print("❌ \(error)") }
    }

    private func deleteOffer() async {
        do {
            try await ServiceOfferService.shared.deleteOffer(offerId: offer.id)
            onChange?()
            dismiss()
        } catch { print("❌ \(error)") }
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
        } catch { print("❌ \(error)") }
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
