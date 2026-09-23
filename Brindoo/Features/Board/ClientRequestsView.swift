//
//  ClientRequestsView.swift
//  Brindoo
//
//  Bacheca inversa.
//  CLIENTE: le sue richieste (pubblica, chiudi, elimina).
//  PROFESSIONISTA: sfoglia le richieste aperte e contatta il cliente in chat.
//

import SwiftUI

struct ClientRequestsView: View {

    @Environment(SessionStore.self) private var session

    @State private var requests: [ClientRequest] = []
    /// Professionista che era cliente: le richieste pubblicate allora, da
    /// poter ancora chiudere o eliminare (prima restavano orfane in bacheca).
    @State private var ownRequests: [ClientRequest] = []
    @State private var clientProfiles: [UUID: Profile] = [:]
    @State private var categories: [ServiceCategory] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var showCreate = false

    // Apertura chat (lato professionista)
    @State private var navigateToChat: Conversation?
    @State private var chatPartner: Profile?
    @State private var contactingId: UUID?

    // Limite di richieste aperte (piano gratuito)
    @State private var showLimitPaywall: Bool = false
    @State private var limitMessage: String = ""
    @State private var showPaywallSheet: Bool = false
    /// Errori che non c'entrano con l'abbonamento: niente invito a Pro.
    @State private var actionError: String?

    private var isClient: Bool {
        session.currentProfile?.role == .client
    }

    /// Il posto in cima e' un vantaggio Pro del cliente. Lo vede il
    /// professionista che sfoglia, ma anche il cliente sulle proprie
    /// richieste: se lo paga, deve accorgersi che c'e'.
    private func isFeatured(_ request: ClientRequest) -> Bool {
        guard request.status == .open else { return false }
        let author = isMine(request) ? session.currentProfile : clientProfiles[request.clientId]
        return author?.isPro == true
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(.brindooCoral)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if loadFailed {
                BrindooErrorState(message: BrindooText.loadError("le richieste")) {
                    Task { await load() }
                }
            } else if requests.isEmpty && ownRequests.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color.brindooBackground)
        .navigationTitle(isClient ? "Le mie richieste" : "Richieste dei clienti")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if isClient {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.brindooCoral)
                    }
                    .accessibilityLabel("Pubblica una richiesta")
                }
            }
        }
        .sheet(isPresented: $showCreate, onDismiss: {
            Task { await load() }
        }) {
            CreateClientRequestView()
        }
        .navigationDestination(item: $navigateToChat) { conv in
            if let partner = chatPartner {
                ChatView(conversation: conv, otherUser: partner)
            }
        }
        .alert("Limite raggiunto", isPresented: $showLimitPaywall) {
            Button("Annulla", role: .cancel) {}
            Button("Scopri Pro") {
                showLimitPaywall = false
                showPaywallSheet = true
            }
        } message: {
            Text(limitMessage)
        }
        .sheet(isPresented: $showPaywallSheet) {
            PaywallView()
        }
        .alert(
            "Non riuscito",
            isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })
        ) {
            Button("Ok") { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Stati

    @ViewBuilder
    private var emptyState: some View {
        if isClient {
            BrindooEmptyState(
                icon: "megaphone",
                title: "Nessuna richiesta pubblicata",
                message: "Racconta cosa cerchi (es. \"Fotografo per matrimonio a settembre\") e lascia che i professionisti ti contattino.",
                actionTitle: "Pubblica una richiesta",
                action: { showCreate = true }
            )
        } else {
            BrindooEmptyState(
                icon: "megaphone",
                title: "Nessuna richiesta aperta",
                message: "Quando un cliente pubblica una richiesta la troverai qui."
            )
        }
    }

    /// Azioni del cliente sulla propria richiesta, condivise dal menu a
    /// vista e da quello che compare tenendo premuto.
    @ViewBuilder
    private func requestActions(_ request: ClientRequest) -> some View {
        if isMine(request) {
            if request.status == .open {
                Button {
                    Task { await close(request) }
                } label: {
                    Label("Segna come chiusa", systemImage: "checkmark.circle")
                }
            } else if isClient && !request.isExpired {
                // Una richiesta con la data passata non si riapre: se ne pubblica
                // una nuova. Da professionista le vecchie si chiudono, non si riaprono.
                Button {
                    Task { await reopen(request) }
                } label: {
                    Label("Riapri", systemImage: "arrow.counterclockwise")
                }
            }
            Button(role: .destructive) {
                Task { await delete(request) }
            } label: {
                Label("Elimina", systemImage: BrindooIcon.delete)
            }
        }
    }

    private func isMine(_ request: ClientRequest) -> Bool {
        request.clientId == session.userID
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(BrindooFont.titleSmall)
            .foregroundStyle(Color.brindooTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: BrindooSpacing.md) {
                if !isClient && !ownRequests.isEmpty {
                    sectionTitle("Le tue richieste da cliente")
                    ForEach(ownRequests) { request in
                        requestCard(request)
                    }
                    if !requests.isEmpty {
                        sectionTitle("Richieste dei clienti")
                    }
                }
                ForEach(requests) { request in
                    requestCard(request)
                }
            }
            .padding(BrindooSpacing.md)
            .brindooReadableWidth()
        }
    }

    @ViewBuilder
    private func requestCard(_ request: ClientRequest) -> some View {
                    ClientRequestCard(
                        request: request,
                        category: categories.first { $0.id == request.categoryId },
                        clientProfile: isMine(request) ? nil : clientProfiles[request.clientId],
                        featured: isFeatured(request),
                        isContacting: contactingId == request.id,
                        onContact: isMine(request) ? nil : { Task { await contact(request) } }
                    )
                    .contextMenu { requestActions(request) }
                    // Il tenere premuto non lo scopre nessuno: le stesse
                    // azioni stanno anche dietro un bottone sempre visibile.
                    .overlay(alignment: .topTrailing) {
                        if isMine(request) {
                            Menu {
                                requestActions(request)
                            } label: {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.system(size: 20))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.brindooTextSecondary)
                                    .padding(BrindooSpacing.xs)
                            }
                            .accessibilityLabel("Azioni sulla richiesta")
                        }
                    }
    }

    // MARK: - Dati

    private func load() async {
        isLoading = requests.isEmpty
        loadFailed = false
        defer { isLoading = false }
        do {
            categories = (try? await CategoryService.shared.fetchCategories()) ?? []
            if isClient {
                requests = try await ClientRequestService.shared.fetchMyRequests()
            } else {
                // Ordine gia' deciso dal database (Pro > urgenti > recenti):
                // riordinare qui rimescolerebbe solo le 100 righe scaricate.
                // Chi ha bloccato o è stato bloccato non si vede e non si contatta.
                requests = try await ClientRequestService.shared.fetchOpenRequests()
                    .filter { !BlockService.shared.isBlockingOrBlocked($0.clientId) }
                ownRequests = (try? await ClientRequestService.shared.fetchMyRequests()) ?? []
                await loadClientProfiles()
            }
        } catch {
            loadFailed = true
            BrindooLog.error("Caricamento richieste: \(error)")
        }
    }

    private func loadClientProfiles() async {
        let missing = Set(requests.map { $0.clientId }).subtracting(clientProfiles.keys)
        guard !missing.isEmpty else { return }
        // Una richiesta sola per tutti i clienti della bacheca.
        let profiles = (try? await ProfileService.shared.fetchProfiles(ids: Array(missing))) ?? []
        for profile in profiles { clientProfiles[profile.id] = profile }
    }

    // MARK: - Azioni

    private func contact(_ request: ClientRequest) async {
        guard let profile = clientProfiles[request.clientId] else {
            actionError = "Profilo del cliente non disponibile. Aggiorna e riprova."
            return
        }
        contactingId = request.id
        defer { contactingId = nil }
        do {
            let conv = try await ConversationService.shared
                .findOrCreateConversationAsOrganizer(clientId: request.clientId)
            chatPartner = profile
            navigateToChat = conv
        } catch {
            // Prima il tocco falliva senza dire nulla.
            actionError = BrindooErrorText.serverRule(error) ?? "Impossibile aprire la chat. Riprova."
            BrindooLog.error("Contatto richiesta: \(error)")
        }
    }

    private func close(_ request: ClientRequest) async {
        do {
            try await ClientRequestService.shared.close(requestId: request.id)
            BrindooHaptics.notify(.success)
            await load()
        } catch {
            actionError = "Impossibile chiudere la richiesta. Riprova."
            BrindooLog.error("\(error)")
        }
    }

    private func reopen(_ request: ClientRequest) async {
        do {
            try await ClientRequestService.shared.reopen(requestId: request.id)
            await load()
        } catch let limitError as BrindooLimitError {
            limitMessage = limitError.errorDescription ?? "Limite raggiunto."
            showLimitPaywall = true
        } catch {
            // Anche il fallimento generico deve dire qualcosa: prima il tocco
            // sulla riapertura non lasciava alcuna traccia a schermo.
            actionError = "Impossibile riaprire la richiesta. Riprova."
            BrindooLog.error("\(error)")
        }
    }

    private func delete(_ request: ClientRequest) async {
        do {
            try await ClientRequestService.shared.delete(requestId: request.id)
            requests.removeAll { $0.id == request.id }
        } catch {
            actionError = "Impossibile eliminare la richiesta. Riprova."
            BrindooLog.error("\(error)")
        }
    }
}

// MARK: - Card richiesta

struct ClientRequestCard: View {
    let request: ClientRequest
    let category: ServiceCategory?
    /// Profilo del cliente (mostrato solo lato professionista).
    let clientProfile: Profile?
    /// La richiesta occupa il posto in cima pagato con Pro.
    var featured: Bool = false
    var isContacting: Bool = false
    /// Presente solo lato professionista.
    var onContact: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack(alignment: .top) {
                Text(request.title)
                    .font(BrindooFont.titleSmall)
                    .foregroundStyle(Color.brindooTextPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                statusPill
            }

            // Le etichette stanno su una riga propria: accanto al titolo, su
            // schermo piccolo o con testo grande, lo schiacciavano.
            if featured || showsUrgent {
                HStack(spacing: BrindooSpacing.xs) {
                    if featured { featuredPill }
                    if showsUrgent { urgentPill }
                }
            }

            if let category {
                HStack(spacing: 4) {
                    Image(systemName: category.icon).font(.system(size: 11))
                    Text(category.name).font(BrindooFont.caption.weight(.medium))
                }
                .padding(.horizontal, BrindooSpacing.sm)
                .padding(.vertical, 3)
                .foregroundStyle(Color.brindooCoral)
                .background(Color.brindooCoral.opacity(0.1))
                .clipShape(Capsule())
            }

            if let description = request.description, !description.isEmpty {
                Text(description)
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .lineLimit(3)
            }

            VStack(alignment: .leading, spacing: BrindooSpacing.xxs) {
                detailRow(icon: "mappin.and.ellipse", text: request.area)
                if let date = request.eventDateDisplay {
                    detailRow(icon: "calendar", text: date)
                }
                if let budget = request.budgetDisplay {
                    detailRow(icon: "eurosign.circle", text: "Budget \(budget)")
                }
            }

            if let clientProfile {
                Divider()
                HStack(spacing: BrindooSpacing.sm) {
                    AvatarView(url: clientProfile.avatarUrl, name: clientProfile.fullName, size: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(clientProfile.displayName)
                            .font(BrindooFont.bodySmall.weight(.semibold))
                        Text(timeAgo(request.createdAt))
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                    Spacer()
                    if let onContact {
                        BrindooButton(
                            "Contatta",
                            style: .primary,
                            size: .small,
                            isLoading: isContacting,
                            action: onContact
                        )
                    }
                }
            }
        }
        .padding(BrindooSpacing.md)
        .brindooSurfaceBackground()
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.md)
                .strokeBorder(Color.brindooBorder, lineWidth: 1)
        )
    }

    private var showsUrgent: Bool {
        request.isUrgent && request.status == .open
    }

    private var featuredPill: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.bubble.fill").font(.system(size: 9))
            Text("In evidenza").font(BrindooFont.scaled(11, weight: .semibold, relativeTo: .caption1))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(Color.brindooCoral)
        .background(Color.brindooCoral.opacity(0.12))
        .clipShape(Capsule())
    }

    private var urgentPill: some View {
        HStack(spacing: 3) {
            Image(systemName: BrindooIcon.flame).font(.system(size: 9))
            Text("Urgente").font(BrindooFont.scaled(11, weight: .semibold, relativeTo: .caption1))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(Color.brindooError)
        .background(Color.brindooError.opacity(0.12))
        .clipShape(Capsule())
    }

    private var statusPill: some View {
        BrindooDotBadge(request.status.displayName, color: request.status.tint)
    }

    @ViewBuilder
    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.brindooCoral)
                .frame(width: 16)
            Text(text)
                .font(BrindooFont.bodySmall)
                .foregroundStyle(Color.brindooTextSecondary)
        }
    }

    private func timeAgo(_ date: Date) -> String {
        BrindooFormat.timeAgoShort(date)
    }
}
