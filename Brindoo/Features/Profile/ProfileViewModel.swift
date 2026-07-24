//
//  ProfileViewModel.swift
//  Brindoo
//
//  Parte "dati" del proprio profilo: categorie, recensioni, portfolio e
//  offerte attive che alimentano la barra "profilo completo".
//  La vista resta interfaccia e navigazione.
//

import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {

    private(set) var organizerCategories: [OrganizerCategoryDetail] = []
    private(set) var reviewSummary: ReviewSummary?
    private(set) var portfolioCount: Int = 0
    private(set) var activeOffersCount: Int = 0

    /// Carica i dati mostrati al professionista. Per il cliente non c'è
    /// nulla da chiedere: il profilo si legge dalla sessione.
    func load(userId: UUID?, isOrganizer: Bool) async {
        guard let userId, isOrganizer else { return }

        do {
            organizerCategories = try await OrganizerCategoriesService.shared.fetchDetailed(organizerId: userId)
        } catch { BrindooLog.error("\(error)") }

        do {
            reviewSummary = try await ReviewService.shared.fetchSummary(organizerId: userId)
        } catch { BrindooLog.error("\(error)") }

        do {
            let items = try await PortfolioService.shared.fetchPortfolio(organizerId: userId)
            portfolioCount = items.count
        } catch { BrindooLog.error("\(error)") }

        // Per la barra "profilo completo": quante offerte attive ha.
        if let offers = try? await ServiceOfferService.shared.fetchMyOffers() {
            activeOffersCount = offers.filter { $0.status == .active }.count
        }
    }
}
