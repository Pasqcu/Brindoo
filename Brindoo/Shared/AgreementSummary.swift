//
//  AgreementSummary.swift
//  Brindoo
//
//  Regole standard di annullamento (mostrate PRIMA di accettare una
//  trattativa) e riepilogo testuale dell'accordo chiuso, condivisibile
//  dal cliente come promemoria scritto di prezzo, data e condizioni.
//

import SwiftUI

// MARK: - Regole di annullamento

/// Regole standard Brindoo, valide salvo diverso accordo scritto in chat.
enum CancellationPolicy {

    static let rules: [String] = [
        "Fino a 30 giorni prima dell'evento: annullamento libero, eventuale acconto restituito.",
        "Da 29 a 7 giorni prima: l'acconto versato resta al professionista, nessun'altra penale.",
        "Meno di 7 giorni prima: il professionista può richiedere l'intero importo pattuito.",
        "Se annulla il professionista: restituzione completa di quanto versato."
    ]

    static let note = "Regole standard Brindoo, valide salvo diverso accordo scritto in chat tra le parti."

    /// Testo unico per il riepilogo condivisibile.
    static var summaryText: String {
        rules.map { "• \($0)" }.joined(separator: "\n")
    }
}

/// Riquadro richiudibile con le regole di annullamento.
/// Da mostrare prima dei pulsanti di accettazione e nell'accordo chiuso.
struct CancellationPolicyRow: View {

    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                ForEach(CancellationPolicy.rules, id: \.self) { rule in
                    HStack(alignment: .top, spacing: BrindooSpacing.xs) {
                        Text("•")
                        Text(rule)
                    }
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                }
                Text(CancellationPolicy.note)
                    .font(BrindooFont.caption.italic())
                    .foregroundStyle(Color.brindooTextSecondary)
                    .padding(.top, 2)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, BrindooSpacing.xs)
        } label: {
            Label("Regole di annullamento", systemImage: "info.circle")
                .font(BrindooFont.caption.weight(.semibold))
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .tint(Color.brindooTextSecondary)
        .padding(BrindooSpacing.sm)
        .background(Color.brindooBackground)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
    }
}

// MARK: - Riepilogo accordo

enum AgreementSummary {

    /// Testo del riepilogo per un accordo chiuso: chi, cosa, quanto,
    /// quando, acconto e regole di annullamento.
    static func text(offer: ServiceOffer, organizerName: String?, proposal: OfferProposal) -> String {
        var lines: [String] = []
        lines.append("RIEPILOGO ACCORDO — Brindoo")
        lines.append("")
        lines.append("Servizio: \(offer.title)")
        if let organizerName, !organizerName.isEmpty {
            lines.append("Professionista: \(organizerName)")
        }
        lines.append("Prezzo concordato: \(proposal.currentPriceDisplay)")
        if let date = proposal.eventDateDisplay {
            lines.append("Data evento: \(date)")
        }
        lines.append("Acconto: \(proposal.isDepositPaid ? "versato" : "non ancora versato")")
        if let message = proposal.lastMessage, !message.isEmpty {
            lines.append("Note: \(message)")
        }
        lines.append("")
        lines.append("Regole di annullamento:")
        lines.append(CancellationPolicy.summaryText)
        lines.append(CancellationPolicy.note)
        lines.append("")
        lines.append("Brindoo mette in contatto le parti e non è parte dell'accordo.")
        return lines.joined(separator: "\n")
    }
}
