//
//  ReviewsListView.swift
//  Brindoo
//
//  Lista delle recensioni ricevute da un organizzatore.
//

import SwiftUI

struct ReviewsListView: View {
    
    let organizer: Profile
    
    @Environment(SessionStore.self) private var session
    
    @State private var reviews: [Review] = []
    @State private var rating: OrganizerRating?
    @State private var clientsMap: [UUID: Profile] = [:]
    @State private var myReview: Review?
    
    @State private var isLoading: Bool = true
    @State private var showWriteReview: Bool = false
    @State private var reviewToReport: Review?
    @State private var reviewToReply: Review?
    @State private var fullScreenPhotoUrl: FullScreenPhoto?

    /// Foto recensione aperta a schermo intero.
    struct FullScreenPhoto: Identifiable {
        let id = UUID()
        let url: String
    }

    private var isOrganizerOwner: Bool {
        session.userID == organizer.id
    }
    /// True se il cliente ha una trattativa conclusa con questo organizzatore.
    @State private var hasAcceptedDeal: Bool = false
    
    var body: some View {
        Group {
            if isLoading {
                ScrollView {
                    LazyVStack(spacing: BrindooSpacing.md) {
                        ForEach(0..<5, id: \.self) { _ in BrindooSkeletonCard() }
                    }
                    .padding(BrindooSpacing.lg)
                }
                .disabled(true)
            } else {
                content
            }
        }
        .background(Color.brindooBackground)
        .navigationTitle("Recensioni")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAllData()
        }
        .refreshable {
            await loadAllData()
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewView(
                organizer: organizer,
                existingReview: myReview
            ) {
                Task { await loadAllData() }
            }
        }
        .sheet(item: $reviewToReport) { review in
            ReportSheet(
                targetType: .review,
                targetId: review.id,
                targetLabel: "questa recensione"
            )
        }
        .sheet(item: $reviewToReply) { review in
            ReplyToReviewSheet(review: review) {
                Task { await loadAllData() }
            }
        }
        .fullScreenCover(item: $fullScreenPhotoUrl) { photo in
            FullScreenImageView(url: photo.url) {
                fullScreenPhotoUrl = nil
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                // Sommario rating
                if let rating {
                    ratingSummary(rating)
                }
                
                // Bottone scrivi recensione (solo clienti, non se sono io l'organizzatore).
                // Si può recensire solo dopo una trattativa conclusa, oppure modificare
                // una recensione già scritta.
                if canWriteReview {
                    if myReview != nil {
                        BrindooButton(
                            "Modifica la tua recensione",
                            style: .primary,
                            size: .large,
                            icon: "pencil"
                        ) {
                            showWriteReview = true
                        }
                    } else if hasAcceptedDeal {
                        BrindooButton(
                            "Scrivi una recensione",
                            style: .primary,
                            size: .large,
                            icon: "star.fill"
                        ) {
                            showWriteReview = true
                        }
                    } else {
                        lockedReviewHint
                    }
                }
                
                if reviews.isEmpty {
                    emptyView
                        .padding(.top, BrindooSpacing.xl)
                } else {
                    Divider()
                    
                    Text("Tutte le recensioni")
                        .font(BrindooFont.titleMedium)
                    
                    ForEach(reviews) { review in
                        reviewCard(review)
                    }
                }
            }
            .padding(BrindooSpacing.lg)
        }
    }
    
    @ViewBuilder
    private var lockedReviewHint: some View {
        HStack(alignment: .top, spacing: BrindooSpacing.sm) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 18))
                .foregroundStyle(Color.brindooCoral)
            VStack(alignment: .leading, spacing: 2) {
                Text("Recensioni verificate")
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                Text("Potrai lasciare una recensione dopo aver concluso una trattativa con questo professionista.")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(BrindooSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooCoral.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    // MARK: - Sommario rating
    
    @ViewBuilder
    private func ratingSummary(_ rating: OrganizerRating) -> some View {
        HStack(spacing: BrindooSpacing.lg) {
            VStack(alignment: .leading, spacing: BrindooSpacing.xxs) {
                HStack(spacing: BrindooSpacing.xs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.brindooCoral)
                    
                    Text(rating.displayRating)
                        .font(BrindooFont.displayMedium)
                        .foregroundStyle(Color.brindooTextPrimary)
                }
                
                Text(rating.displayReviewCount)
                    .font(BrindooFont.bodyMedium)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            
            Spacer()
            
            if rating.reviewCount > 0 {
                StarRatingView(
                    rating: rating.avgRating,
                    mode: .display,
                    size: 22
                )
            }
        }
        .padding(BrindooSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }
    
    // MARK: - Empty
    
    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: BrindooSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.brindooCoral.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "star")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.brindooCoral)
            }
            
            Text("Nessuna recensione")
                .font(BrindooFont.titleSmall)
            
            Text(canWriteReview
                 ? "Sii il primo a recensire questo organizzatore"
                 : "Le recensioni dei clienti appariranno qui")
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BrindooSpacing.xl)
    }
    
    // MARK: - Card recensione

    @ViewBuilder
    private func reviewCard(_ review: Review) -> some View {
        let client = clientsMap[review.clientId]
        let isMine = review.clientId == session.userID

        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack(spacing: BrindooSpacing.sm) {
                AvatarView(
                    url: client?.avatarUrl,
                    name: client?.fullName,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: BrindooSpacing.xxs) {
                        Text(client?.fullName ?? "Cliente")
                            .font(BrindooFont.titleSmall)

                        if isMine {
                            Text("(tu)")
                                .font(BrindooFont.caption)
                                .foregroundStyle(Color.brindooCoral)
                        }
                    }

                    HStack(spacing: BrindooSpacing.xs) {
                        StarRatingView(
                            rating: Double(review.rating),
                            mode: .display,
                            size: 12
                        )
                        Text(review.createdAtDisplay)
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }

                    if review.isVerified {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                            Text("Verificata")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color.brindooSuccess)
                    }
                }

                Spacer()

                // Menu segnalazione disponibile su recensioni altrui.
                if !isMine {
                    Menu {
                        Button(role: .destructive) {
                            reviewToReport = review
                        } label: {
                            Label("Segnala recensione", systemImage: "exclamationmark.bubble")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.brindooTextSecondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                }
            }

            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(BrindooFont.bodyMedium)
                    .foregroundStyle(Color.brindooTextPrimary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Foto dell'evento allegata dal cliente
            if let photo = review.photoUrl, !photo.isEmpty, let url = URL(string: photo) {
                Button {
                    fullScreenPhotoUrl = FullScreenPhoto(url: photo)
                } label: {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        BrindooSkeleton(cornerRadius: BrindooRadius.sm)
                    }
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Foto dell'evento, tocca per ingrandire")
            }

            // Risposta dell'organizzatore
            if let reply = review.reply, !reply.isEmpty {
                HStack(alignment: .top, spacing: BrindooSpacing.xs) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.brindooCoral)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Risposta di \(organizer.fullName ?? "organizzatore")")
                            .font(BrindooFont.caption.weight(.semibold))
                            .foregroundStyle(Color.brindooCoral)
                        Text(reply)
                            .font(BrindooFont.bodySmall)
                            .foregroundStyle(Color.brindooTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(BrindooSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brindooCoral.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
            } else if isOrganizerOwner {
                Button {
                    reviewToReply = review
                } label: {
                    Label("Rispondi", systemImage: "arrowshape.turn.up.left")
                        .font(BrindooFont.bodySmall.weight(.semibold))
                        .foregroundStyle(Color.brindooCoral)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(BrindooSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooBackground)
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.lg)
                .strokeBorder(
                    isMine ? Color.brindooCoral.opacity(0.5) : Color.brindooBorder,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
    }
    
    // MARK: - Helpers
    
    private var canWriteReview: Bool {
        // Solo i clienti possono recensire, non se l'organizzatore è se stesso
        guard session.currentProfile?.role == .client else { return false }
        guard session.userID != organizer.id else { return false }
        return true
    }
    
    // MARK: - Caricamento
    
    private func loadAllData() async {
        isLoading = true
        defer { isLoading = false }
        
        async let ratingTask = ReviewService.shared.fetchRating(organizerId: organizer.id)
        async let reviewsTask = ReviewService.shared.fetchReviews(organizerId: organizer.id)
        async let myReviewTask = ReviewService.shared.myReviewFor(organizerId: organizer.id)
        
        do {
            self.rating = try await ratingTask
            self.reviews = try await reviewsTask
            self.myReview = try await myReviewTask

            // Verifica se il cliente può lasciare una recensione (trattativa conclusa).
            if canWriteReview {
                self.hasAcceptedDeal = (try? await ReviewService.shared.hasAcceptedDeal(withOrganizer: organizer.id)) ?? false
            }

            // Carica i profili dei clienti che hanno recensito
            await loadClients(for: reviews)
        } catch {
            print("❌ Errore caricamento recensioni: \(error)")
        }
    }
    
    private func loadClients(for reviews: [Review]) async {
        let clientIds = Set(reviews.map { $0.clientId })
        
        await withTaskGroup(of: (UUID, Profile?).self) { group in
            for clientId in clientIds {
                if clientsMap[clientId] != nil { continue }
                group.addTask {
                    do {
                        let p = try await ProfileService.shared.fetchProfile(userID: clientId)
                        return (clientId, p)
                    } catch {
                        return (clientId, nil)
                    }
                }
            }
            for await (id, profile) in group {
                if let profile { clientsMap[id] = profile }
            }
        }
    }
}

// MARK: - Sheet risposta recensione

struct ReplyToReviewSheet: View {
    let review: Review
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.md) {
                    Text("Rispondi pubblicamente a questa recensione. La tua risposta sarà visibile a tutti.")
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)

                    TextField("Scrivi la tua risposta…", text: $text, axis: .vertical)
                        .lineLimit(4...10)
                        .font(BrindooFont.bodyLarge)
                        .padding(BrindooSpacing.md)
                        .background(Color.brindooSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: BrindooRadius.md)
                                .strokeBorder(Color.brindooBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                        .disabled(isLoading)

                    if let error {
                        Text(error)
                            .font(BrindooFont.bodySmall)
                            .foregroundStyle(Color.brindooError)
                    }
                }
                .padding(BrindooSpacing.lg)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Rispondi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }.disabled(isLoading)
                }
            }
            .safeAreaInset(edge: .bottom) {
                BrindooButton("Pubblica risposta", style: .primary, size: .large, isLoading: isLoading,
                              isDisabled: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    Task { await submit() }
                }
                .padding(.horizontal, BrindooSpacing.lg)
                .padding(.vertical, BrindooSpacing.sm)
                .background(Color.brindooBackground)
            }
            .onAppear { text = review.reply ?? "" }
        }
    }

    private func submit() async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await ReviewService.shared.replyToReview(reviewId: review.id, reply: text)
            BrindooHaptics.notify(.success)
            onSuccess()
            dismiss()
        } catch {
            self.error = "Impossibile pubblicare la risposta. Riprova."
            print("❌ \(error)")
        }
    }
}
