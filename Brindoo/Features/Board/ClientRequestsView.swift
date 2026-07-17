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
    @State private var clientProfiles: [UUID: Profile] = [:]
    @State private var categories: [ServiceCategory] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var showCreate = false

    // Apertura chat (lato professionista)
    @State private var navigateToChat: Conversation?
    @State private var chatPartner: Profile?
    @State private var contactingId: UUID?

    private var isClient: Bool {
        session.currentProfile?.role == .client
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(.brindooCoral)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if loadFailed {
                BrindooErrorState(message: "Impossibile caricare le richieste") {
                    Task { await load() }
                }
            } else if requests.isEmpty {
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

    @ViewBuilder
    private var list: some View {
        ScrollView {
            LazyVStack(spacing: BrindooSpacing.md) {
                ForEach(requests) { request in
                    ClientRequestCard(
                        request: request,
                        category: categories.first { $0.id == request.categoryId },
                        clientProfile: isClient ? nil : clientProfiles[request.clientId],
                        isContacting: contactingId == request.id,
                        onContact: isClient ? nil : { Task { await contact(request) } }
                    )
                    .contextMenu {
                        if isClient {
                            if request.status == .open {
                                Button {
                                    Task { await close(request) }
                                } label: {
                                    Label("Segna come chiusa", systemImage: "checkmark.circle")
                                }
                            } else {
                                Button {
                                    Task { await reopen(request) }
                                } label: {
                                    Label("Riapri", systemImage: "arrow.counterclockwise")
                                }
                            }
                            Button(role: .destructive) {
                                Task { await delete(request) }
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                    }
                }

                if isClient {
                    Text("Tieni premuto su una richiesta per chiuderla o eliminarla.")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .padding(.top, BrindooSpacing.xs)
                }
            }
            .padding(BrindooSpacing.md)
            .brindooReadableWidth()
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
                // Le richieste urgenti risalgono in cima, a parità vince la più recente.
                requests = try await ClientRequestService.shared.fetchOpenRequests()
                    .sorted {
                        if $0.isUrgent != $1.isUrgent { return $0.isUrgent }
                        return $0.createdAt > $1.createdAt
                    }
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
        await withTaskGroup(of: Profile?.self) { group in
            for id in missing {
                group.addTask {
                    try? await ProfileService.shared.fetchProfile(userID: id)
                }
            }
            for await profile in group {
                if let profile { clientProfiles[profile.id] = profile }
            }
        }
    }

    // MARK: - Azioni

    private func contact(_ request: ClientRequest) async {
        guard let profile = clientProfiles[request.clientId] else { return }
        contactingId = request.id
        defer { contactingId = nil }
        do {
            let conv = try await ConversationService.shared
                .findOrCreateConversationAsOrganizer(clientId: request.clientId)
            chatPartner = profile
            navigateToChat = conv
        } catch {
            BrindooLog.error("Contatto richiesta: \(error)")
        }
    }

    private func close(_ request: ClientRequest) async {
        do {
            try await ClientRequestService.shared.close(requestId: request.id)
            BrindooHaptics.notify(.success)
            await load()
        } catch { BrindooLog.error("\(error)") }
    }

    private func reopen(_ request: ClientRequest) async {
        do {
            try await ClientRequestService.shared.reopen(requestId: request.id)
            await load()
        } catch { BrindooLog.error("\(error)") }
    }

    private func delete(_ request: ClientRequest) async {
        do {
            try await ClientRequestService.shared.delete(requestId: request.id)
            requests.removeAll { $0.id == request.id }
        } catch { BrindooLog.error("\(error)") }
    }
}

// MARK: - Card richiesta

struct ClientRequestCard: View {
    let request: ClientRequest
    let category: ServiceCategory?
    /// Profilo del cliente (mostrato solo lato professionista).
    let clientProfile: Profile?
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
                if request.isUrgent && request.status == .open {
                    urgentPill
                }
                statusPill
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
                        Text(clientProfile.fullName ?? "Cliente")
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
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.md)
                .strokeBorder(Color.brindooBorder, lineWidth: 1)
        )
    }

    private var urgentPill: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill").font(.system(size: 9))
            Text("Urgente").font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(Color.brindooError)
        .background(Color.brindooError.opacity(0.12))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var statusPill: some View {
        let isOpen = request.status == .open
        HStack(spacing: 4) {
            Circle()
                .fill(isOpen ? Color.brindooSuccess : Color.brindooTextSecondary)
                .frame(width: 6, height: 6)
            Text(request.status.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isOpen ? Color.brindooSuccess : Color.brindooTextSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((isOpen ? Color.brindooSuccess : Color.brindooTextSecondary).opacity(0.1))
        .clipShape(Capsule())
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
