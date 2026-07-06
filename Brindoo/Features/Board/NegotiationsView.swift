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

    @State private var proposals: [OfferProposal] = []
    @State private var offerMap: [UUID: ServiceOffer] = [:]
    @State private var profileMap: [UUID: Profile] = [:]
    @State private var isLoading: Bool = true
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
            if isLoading {
                ScrollView {
                    LazyVStack(spacing: BrindooSpacing.sm) {
                        ForEach(0..<6, id: \.self) { _ in BrindooSkeletonCard() }
                    }
                    .padding(BrindooSpacing.md)
                }
                .disabled(true)
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
                    Image(systemName: "calendar")
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
        VStack(spacing: BrindooSpacing.md) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.brindooCoral.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.brindooCoral)
            }
            Text("Nessuna trattativa")
                .font(BrindooFont.titleMedium)
            Text("Le proposte e controproposte sulle offerte appariranno qui")
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BrindooSpacing.xl)
            Spacer()
        }
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
                            Image(systemName: "star.fill")
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
                }
            }
        }
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
            print("❌ \(error)")
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
                if let eventDate = proposal.eventDateDisplay {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
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
                Text(proposal.updatedAtDisplay)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(proposal.currentPriceDisplay)
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brindooCoral)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    // MARK: - Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            proposals = try await OfferProposalService.shared.fetchMyOngoingProposals()
            await loadRelated()
        } catch {
            print("❌ \(error)")
        }
    }

    private func loadRelated() async {
        let offerIds: Set<UUID> = Set(proposals.map { $0.offerId })
        var profileIds: Set<UUID> = Set(proposals.flatMap { [$0.clientId, $0.organizerId] })
        if let me = currentUserId { profileIds.remove(me) }

        await withTaskGroup(of: Void.self) { group in
            for id in offerIds where offerMap[id] == nil {
                group.addTask {
                    if let o = try? await ServiceOfferService.shared.fetchOffer(id: id) {
                        await MainActor.run { offerMap[id] = o }
                    }
                }
            }
            for id in profileIds where profileMap[id] == nil {
                group.addTask {
                    if let p = try? await ProfileService.shared.fetchProfile(userID: id) {
                        await MainActor.run { profileMap[id] = p }
                    }
                }
            }
        }
    }
}
