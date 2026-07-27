//
//  ReviewService.swift
//  Brindoo
//
//  Service per gestire le recensioni e il rating aggregato degli organizzatori.
//

import Foundation
import Supabase

@MainActor
final class ReviewService {

    static let shared = ReviewService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Lista recensioni di un organizzatore

    func fetchReviews(organizerId: UUID) async throws -> [Review] {
        do {
            let reviews: [Review] = try await client
                .from("reviews")
                .select()
                .eq("organizer_id", value: organizerId)
                .order("created_at", ascending: false)
                .execute()
                .value

            BrindooLog.info("Caricate \(reviews.count) recensioni")
            return reviews
        } catch {
            BrindooLog.error("Errore caricamento recensioni: \(error)")
            throw error
        }
    }

    // MARK: - Rating aggregato

    /// Recupera rating medio + conteggio per un organizzatore
    func fetchRating(organizerId: UUID) async throws -> OrganizerRating {
        do {
            let ratings: [OrganizerRating] = try await client
                .from("organizer_ratings")
                .select()
                .eq("organizer_id", value: organizerId)
                .limit(1)
                .execute()
                .value

            if let rating = ratings.first {
                return rating
            } else {
                return OrganizerRating(
                    organizerId: organizerId,
                    avgRating: 0,
                    reviewCount: 0
                )
            }
        } catch {
            BrindooLog.error("Errore caricamento rating: \(error)")
            throw error
        }
    }

    /// Rating aggregati per più organizzatori in una sola query.
    func fetchRatings(organizerIds: [UUID]) async throws -> [UUID: OrganizerRating] {
        guard !organizerIds.isEmpty else { return [:] }
        let ratings: [OrganizerRating] = try await client
            .from("organizer_ratings")
            .select()
            .in("organizer_id", values: organizerIds.map { $0.uuidString })
            .execute()
            .value
        var out: [UUID: OrganizerRating] = [:]
        for r in ratings { out[r.organizerId] = r }
        return out
    }

    /// Restituisce il summary di rating, oppure `nil` se non ci sono recensioni.
    func fetchSummary(organizerId: UUID) async throws -> ReviewSummary? {
        let summary = try await fetchRating(organizerId: organizerId)
        return summary.reviewCount > 0 ? summary : nil
    }

    // MARK: - Verifica recensione esistente

    /// Recupera la recensione del cliente corrente per questo organizzatore (se esiste)
    func myReviewFor(organizerId: UUID) async throws -> Review? {
        guard let userId = SupabaseManager.shared.currentUserID else { return nil }

        do {
            let reviews: [Review] = try await client
                .from("reviews")
                .select()
                .eq("organizer_id", value: organizerId)
                .eq("client_id", value: userId)
                .limit(1)
                .execute()
                .value
            return reviews.first
        } catch {
            BrindooLog.error("Errore verifica recensione: \(error)")
            return nil
        }
    }

    // MARK: - Evento svolto (per recensioni verificate)

    /// True se il cliente corrente ha almeno una trattativa accettata con questo
    /// organizzatore **e il servizio è già stato reso**: appuntamento segnato
    /// come "svolto" oppure data dell'evento ormai passata.
    ///
    /// L'accordo da solo non basta: una recensione scritta prima della festa
    /// non dice nulla sul lavoro e il professionista la sente ingiusta.
    func hasCompletedDeal(withOrganizer organizerId: UUID) async throws -> Bool {
        guard let userId = SupabaseManager.shared.currentUserID else { return false }
        let today = BrindooFormat.todayString
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client
            .from("offer_proposals")
            .select("id")
            .eq("client_id", value: userId)
            .eq("organizer_id", value: organizerId)
            .eq("status", value: OfferProposalStatus.accepted.rawValue)
            .or("booking_status.eq.\(BookingStatus.completed.rawValue),event_date.lt.\(today)")
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    // MARK: - Crea recensione

    @discardableResult
    func createReview(
        organizerId: UUID,
        rating: Int,
        comment: String?,
        applicationId: UUID? = nil,
        photoUrl: String? = nil
    ) async throws -> Review {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw BrindooServiceError.notLoggedIn
        }

        guard userId != organizerId else {
            throw BrindooServiceError.invalidInput("Non puoi recensire te stesso")
        }

        guard (1...5).contains(rating) else {
            throw BrindooServiceError.invalidInput("Voto non valido")
        }

        let trimmedComment = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalComment = (trimmedComment?.isEmpty ?? true) ? nil : trimmedComment

        // Verificata se il servizio con questo organizzatore è già stato reso.
        let isVerified = (try? await hasCompletedDeal(withOrganizer: organizerId)) ?? false

        let payload = NewReview(
            client_id: userId,
            organizer_id: organizerId,
            application_id: applicationId,
            rating: rating,
            comment: finalComment,
            verified: isVerified,
            photo_url: photoUrl
        )

        do {
            let review: Review = try await client
                .from("reviews")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value

            BrindooLog.info("Recensione creata: \(review.id)")
            return review
        } catch {
            BrindooLog.error("Errore creazione recensione: \(error)")
            throw error
        }
    }

    // MARK: - Aggiorna recensione esistente

    @discardableResult
    func updateReview(
        reviewId: UUID,
        rating: Int,
        comment: String?,
        photoUrl: String? = nil
    ) async throws -> Review {
        guard (1...5).contains(rating) else {
            throw BrindooServiceError.invalidInput("Voto non valido")
        }

        let trimmedComment = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalComment: String? = (trimmedComment?.isEmpty ?? true) ? nil : trimmedComment

        struct UpdatePayload: Encodable {
            let rating: Int
            let comment: String?
            let photo_url: String?

            // Encoding esplicito: nil deve diventare NULL sul DB (per poter
            // rimuovere commento/foto), non "campo omesso = invariato".
            enum CodingKeys: String, CodingKey { case rating, comment, photo_url }
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(rating, forKey: .rating)
                try c.encode(comment, forKey: .comment)
                try c.encode(photo_url, forKey: .photo_url)
            }
        }

        let payload = UpdatePayload(rating: rating, comment: finalComment, photo_url: photoUrl)

        do {
            let review: Review = try await client
                .from("reviews")
                .update(payload)
                .eq("id", value: reviewId)
                .select()
                .single()
                .execute()
                .value

            BrindooLog.info("Recensione aggiornata")
            return review
        } catch {
            BrindooLog.error("Errore update recensione: \(error)")
            throw error
        }
    }

    // MARK: - Risposta dell'organizzatore

    /// L'organizzatore risponde a una recensione ricevuta.
    @discardableResult
    func replyToReview(reviewId: UUID, reply: String) async throws -> Review {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        struct U: Encodable { let reply: String?; let reply_at: String? }
        let payload = U(
            reply: trimmed.isEmpty ? nil : trimmed,
            reply_at: trimmed.isEmpty ? nil : BrindooFormat.isoNow
        )
        return try await client
            .from("reviews")
            .update(payload)
            .eq("id", value: reviewId)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Cancella recensione

    func deleteReview(reviewId: UUID) async throws {
        do {
            try await client
                .from("reviews")
                .delete()
                .eq("id", value: reviewId)
                .execute()
            BrindooLog.info("Recensione eliminata")
        } catch {
            BrindooLog.error("Errore cancellazione recensione: \(error)")
            throw error
        }
    }
}
