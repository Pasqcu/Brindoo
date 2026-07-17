//
//  GdprRightsView.swift
//  Brindoo
//
//  "I tuoi dati e i tuoi diritti": spiegazione semplice dei diritti GDPR
//  con rimando alle funzioni già presenti in app, ed esportazione dei
//  propri dati in un file leggibile (diritto alla portabilità).
//

import SwiftUI

struct GdprRightsView: View {

    @Environment(SessionStore.self) private var session

    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var exportError: String?

    private struct Right: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let text: String
    }

    private let rights: [Right] = [
        Right(icon: "eye", title: "Accesso",
              text: "Puoi vedere in ogni momento i dati del tuo profilo e, con «Scarica i miei dati», ottenerne una copia completa."),
        Right(icon: "pencil", title: "Correzione",
              text: "Puoi modificare nome, foto, bio e ogni altro dato da Profilo → Modifica profilo."),
        Right(icon: "square.and.arrow.down", title: "Portabilità",
              text: "Con «Scarica i miei dati» ottieni un file con profilo, offerte, richieste, trattative: puoi conservarlo o portarlo altrove."),
        Right(icon: "trash", title: "Cancellazione",
              text: "Da Impostazioni → Elimina account rimuovi profilo, foto e contenuti. L'operazione è definitiva."),
        Right(icon: "hand.raised", title: "Opposizione e limitazione",
              text: "Puoi bloccare utenti, disattivare le ricevute di lettura e gestire le notifiche dalle impostazioni di iPhone."),
        Right(icon: "building.columns", title: "Reclamo",
              text: "Se ritieni che i tuoi dati siano trattati in modo scorretto puoi rivolgerti al Garante per la protezione dei dati personali (gpdp.it).")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.md) {
                Text("Il Regolamento europeo (GDPR) ti dà questi diritti sui tuoi dati. Ecco cosa significano e dove trovarli in Brindoo.")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)

                ForEach(rights) { right in
                    HStack(alignment: .top, spacing: BrindooSpacing.sm) {
                        Image(systemName: right.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.brindooCoral)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(right.title)
                                .font(BrindooFont.bodyMedium.weight(.semibold))
                            Text(right.text)
                                .font(BrindooFont.bodySmall)
                                .foregroundStyle(Color.brindooTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(BrindooSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                }

                BrindooButton("Scarica i miei dati", style: .primary, size: .large, icon: "square.and.arrow.down", isLoading: isExporting) {
                    Task { await export() }
                }

                if let exportError {
                    Text(exportError)
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooError)
                }

                Text("Per ogni richiesta sui tuoi dati: supporto@brindoo.app")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .padding(BrindooSpacing.md)
        }
        .background(Color.brindooBackground)
        .navigationTitle("I tuoi dati e diritti")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(
            get: { exportURL.map { ExportFile(url: $0) } },
            set: { _ in exportURL = nil }
        )) { file in
            ActivityShareSheet(items: [file.url])
                .presentationDetents([.medium, .large])
        }
    }

    private struct ExportFile: Identifiable {
        let url: URL
        var id: URL { url }
    }

    /// Raccoglie i dati dell'utente dai servizi esistenti e li salva
    /// in un file JSON leggibile, pronto da condividere o conservare.
    private func export() async {
        isExporting = true
        exportError = nil
        defer { isExporting = false }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            struct Export: Encodable {
                let generatedAt: Date
                let profile: Profile?
                let myOffers: [ServiceOffer]
                let myRequests: [ClientRequest]
                let myProposals: [OfferProposal]
                let reviewsReceived: [Review]
            }

            let isOrganizer = session.currentProfile?.role == .organizer
            let export = Export(
                generatedAt: Date(),
                profile: session.currentProfile,
                myOffers: (try? await ServiceOfferService.shared.fetchMyOffers()) ?? [],
                myRequests: (try? await ClientRequestService.shared.fetchMyRequests()) ?? [],
                myProposals: (try? await OfferProposalService.shared.fetchMyOngoingProposals()) ?? [],
                reviewsReceived: isOrganizer
                    ? ((try? await ReviewService.shared.fetchReviews(organizerId: session.userID ?? UUID())) ?? [])
                    : []
            )

            let data = try encoder.encode(export)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("brindoo-dati-\(BrindooFormat.dayString(from: Date())).json")
            try data.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            exportError = "Esportazione non riuscita. Riprova."
            BrindooLog.error("export dati: \(error)")
        }
    }
}
