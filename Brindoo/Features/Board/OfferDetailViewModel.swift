//
//  OfferDetailViewModel.swift
//  Brindoo
//
//  Parte "dati" del dettaglio offerta: caricamenti, trattative, preferiti,
//  stato dell'offerta. La vista resta interfaccia e navigazione.
//
//  Prima erano 590 righe con grafica e chiamate al server mescolate: ogni
//  ritocco visivo rischiava di toccare i dati e viceversa.
//

import Foundation
import Observation

@MainActor
@Observable
final class OfferDetailViewModel {

    let offer: ServiceOffer

    // Contesto, impostato dalla vista prima del primo caricamento.
    private var userID: UUID?
    private var isOwnOffer: Bool = false
    private var canClientInteract: Bool = false

    // Contenuti dell'offerta
    private(set) var categories: [ServiceCategory] = []
    private(set) var organizerProfile: Profile?
    /// Foto del portfolio dell'organizzatore mostrate nella galleria in alto.
    private(set) var portfolioUrls: [String] = []
    /// Pacchetti prezzo dell'offerta (Base / Completo / Premium).
    private(set) var packages: [OfferPackage] = []

    // Trattativa lato cliente: una sola attiva
    private(set) var myProposal: OfferProposal?

    // Lato organizzatore: proposte ricevute e chi le ha mandate
    private(set) var receivedProposals: [OfferProposal] = []

    /// Accordi chiusi su questa offerta e non annullati: finché ce ne sono,
    /// l'offerta non si elimina.
    var hasConfirmedAgreements: Bool {
        receivedProposals.contains { $0.status == .accepted && $0.effectiveBooking != .cancelled }
    }

    /// Trattative ancora in attesa di risposta: sparirebbero con l'offerta,
    /// e chi le ha aperte va almeno contato prima di confermare.
    var openProposalsCount: Int {
        receivedProposals.filter { $0.status == .pending }.count
    }
    private(set) var clientProfilesMap: [UUID: Profile] = [:]

    // Stato modificabile
    var currentStatus: ServiceOfferStatus
    private(set) var isFavorite: Bool = false
    private(set) var isUpdating: Bool = false
    /// Vero mentre una mossa di trattativa è in volo. Serve a impedire il
    /// doppio tocco: due "Accetta" partiti insieme creavano due proposte
    /// per lo stesso accordo, e poi qualcuno doveva disfarle a mano.
    private(set) var isActing: Bool = false
    var actionError: String?

    init(offer: ServiceOffer) {
        self.offer = offer
        self.currentStatus = offer.status
    }

    func configure(userID: UUID?, isOwnOffer: Bool, canClientInteract: Bool) {
        self.userID = userID
        self.isOwnOffer = isOwnOffer
        self.canClientInteract = canClientInteract
    }

    /// Copertina dell'offerta seguita dalle foto del portfolio (senza doppioni).
    var galleryUrls: [String] {
        var urls: [String] = []
        if let cover = offer.imageUrl { urls.append(cover) }
        for u in portfolioUrls where !urls.contains(u) { urls.append(u) }
        return urls
    }

    // MARK: - Caricamento

    func loadData() async {
        do {
            categories = try await ServiceOfferService.shared.fetchOfferCategories(offerId: offer.id)
        } catch { BrindooLog.error("\(error)") }

        do {
            organizerProfile = try await ProfileService.shared.fetchProfile(userID: offer.organizerId)
        } catch { BrindooLog.error("\(error)") }

        // Foto del portfolio per la galleria (best-effort, massimo 6).
        if let items = try? await PortfolioService.shared.fetchPortfolio(organizerId: offer.organizerId) {
            portfolioUrls = items.prefix(6).map { $0.imageUrl }
        }

        // Pacchetti prezzo (best-effort).
        packages = (try? await OfferPackageService.shared.fetchPackages(offerId: offer.id)) ?? []

        // Cliente: la sua trattativa attiva + stato preferito + traccia visita.
        if canClientInteract {
            do {
                myProposal = try await OfferProposalService.shared.fetchMyActiveProposal(forOffer: offer.id)
            } catch { BrindooLog.error("\(error)") }

            isFavorite = (try? await OfferFavoriteService.shared.isFavorite(offerId: offer.id)) ?? false
            await AnalyticsService.shared.trackOfferView(offerId: offer.id)
        }

        // Organizzatore proprietario: le proposte ricevute.
        if isOwnOffer {
            do {
                receivedProposals = try await OfferProposalService.shared.fetchProposals(forOffer: offer.id)
                await loadClients(for: receivedProposals)
            } catch { BrindooLog.error("\(error)") }
        }
    }

    /// Profili dei clienti che hanno mandato una proposta, in una richiesta
    /// sola invece di una per proposta (prima si scaricava anche l'ultimo
    /// round di trattativa, che però non veniva mostrato da nessuna parte).
    private func loadClients(for proposals: [OfferProposal]) async {
        let ids = Array(Set(proposals.map(\.clientId))).filter { clientProfilesMap[$0] == nil }
        guard !ids.isEmpty else { return }
        let profiles = (try? await ProfileService.shared.fetchProfiles(ids: ids)) ?? []
        for profile in profiles { clientProfilesMap[profile.id] = profile }
    }

    // MARK: - Preferiti

    func toggleFavorite() async {
        let target = !isFavorite
        isFavorite = target // ottimistico: la stella cambia subito
        do {
            if target {
                try await OfferFavoriteService.shared.add(offerId: offer.id)
            } else {
                try await OfferFavoriteService.shared.remove(offerId: offer.id)
            }
        } catch {
            isFavorite = !target // torna indietro se il server rifiuta
            BrindooLog.error("\(error)")
        }
    }

    // MARK: - Trattativa

    /// Svolge un'azione sulla trattativa con le regole valide per tutte:
    /// una sola alla volta (due tocchi rapidi non mandano due proposte),
    /// ricarica dei dati se è andata bene, un messaggio leggibile se no.
    ///
    /// Restituisce nil quando l'azione non è partita o è fallita.
    @discardableResult
    private func perform<T>(
        onFailure failureMessage: String,
        _ work: () async throws -> T
    ) async -> T? {
        guard !isActing else { return nil }
        isActing = true
        defer { isActing = false }
        actionError = nil
        do {
            let result = try await work()
            await loadData()
            return result
        } catch {
            actionError = failureMessage
            BrindooLog.error("\(error)")
            return nil
        }
    }

    /// Accetta al prezzo dato (base o di un pacchetto). L'etichetta del
    /// pacchetto, se presente, finisce nel messaggio della proposta.
    func acceptAtPrice(_ price: Double, label: String?) async {
        await perform(onFailure: "Impossibile inviare la proposta.") {
            _ = try await OfferProposalService.shared.openProposal(
                offer: offer,
                price: price,
                message: label
            )
        }
    }

    /// Accetta la proposta. Restituisce la conversazione aperta e con chi
    /// parlare: la festa e la navigazione le gestisce la vista.
    func acceptProposal(_ proposal: OfferProposal) async -> (conversation: Conversation, partner: Profile?)? {
        let opened = await perform(onFailure: "Impossibile accettare.") {
            try await OfferProposalService.shared.accept(proposal: proposal)
        }
        guard let conv = opened.flatMap({ $0 }) else { return nil }
        let partner = userID == proposal.clientId
            ? organizerProfile
            : clientProfilesMap[proposal.clientId]
        return (conv, partner)
    }

    func rejectProposal(_ proposal: OfferProposal) async {
        await perform(onFailure: "Impossibile rifiutare.") {
            try await OfferProposalService.shared.reject(proposal: proposal)
        }
    }

    func withdrawProposal(_ proposal: OfferProposal) async {
        await perform(onFailure: "Impossibile ritirare.") {
            try await OfferProposalService.shared.withdraw(proposal: proposal)
        }
    }

    // MARK: - Evento

    /// Sposta (o fissa) la data dell'evento e avvisa l'altra parte in chat.
    /// `true` se è andata a buon fine.
    func moveEventDate(_ proposal: OfferProposal, to newDate: String) async -> Bool {
        do {
            try await OfferProposalService.shared.updateEventDate(
                proposal: proposal,
                newDate: newDate,
                offerTitle: offer.title
            )
            await loadData()
            return true
        } catch {
            BrindooLog.error("\(error)")
            return false
        }
    }

    func markBooking(_ proposal: OfferProposal, _ status: BookingStatus) async -> Bool {
        guard !isActing else { return false }
        isActing = true
        defer { isActing = false }
        actionError = nil
        do {
            try await OfferProposalService.shared.updateBookingStatus(proposalId: proposal.id, booking: status)
            if status == .cancelled {
                LocalReminderService.cancelReminder(proposalId: proposal.id)
            }
            await loadData()
            return true
        } catch {
            actionError = "Impossibile aggiornare l'appuntamento."
            BrindooLog.error("\(error)")
            return false
        }
    }

    // MARK: - Gestione offerta (proprietario)

    func dismissOffer() async -> Bool {
        actionError = nil
        do {
            try await OfferDismissalService.shared.dismiss(offerId: offer.id)
            return true
        } catch {
            actionError = "Impossibile nascondere."
            BrindooLog.error("\(error)")
            return false
        }
    }

    func togglePause() async -> Bool {
        isUpdating = true
        defer { isUpdating = false }
        let next: ServiceOfferStatus = (currentStatus == .active) ? .paused : .active
        do {
            try await ServiceOfferService.shared.updateStatus(offerId: offer.id, status: next)
            currentStatus = next
            return true
        } catch {
            BrindooLog.error("\(error)")
            return false
        }
    }

    func deleteOffer() async -> Bool {
        do {
            try await ServiceOfferService.shared.deleteOffer(offerId: offer.id)
            return true
        } catch {
            BrindooLog.error("\(error)")
            return false
        }
    }
}
