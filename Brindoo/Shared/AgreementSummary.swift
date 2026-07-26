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
    ///
    /// Vale come promemoria scritto fra le parti, quindi deve nominarle
    /// entrambe e portare la data in cui l'accordo è stato chiuso: un
    /// foglio con una parte sola e senza data serve a poco se poi si
    /// discute.
    static func text(
        offer: ServiceOffer,
        organizerName: String?,
        clientName: String? = nil,
        proposal: OfferProposal
    ) -> String {
        var lines: [String] = []
        lines.append("RIEPILOGO ACCORDO — Brindoo")
        lines.append("Accordo del \(BrindooFormat.italianDate(from: proposal.updatedAt))")
        lines.append("")
        lines.append("Servizio: \(offer.title)")
        if let organizerName, !organizerName.isEmpty {
            lines.append("Professionista: \(organizerName)")
        }
        if let clientName, !clientName.isEmpty {
            lines.append("Cliente: \(clientName)")
        }
        lines.append("Prezzo concordato: \(proposal.currentPriceDisplay)")
        if let date = proposal.eventDateDisplay {
            lines.append("Data evento: \(date)")
        } else {
            // Il silenzio si legge come dimenticanza: meglio dichiararlo.
            lines.append("Data evento: ancora da definire")
        }
        // Nel riepilogo condivisibile diciamo anche quanto e come.
        if proposal.isDepositPaid {
            let amount = proposal.depositAmountDisplay.map { " di \($0)" } ?? ""
            let method = proposal.depositMethod.map { " (\($0.shortLabel))" } ?? ""
            lines.append("Acconto\(amount)\(method): versato e confermato")
        } else if proposal.isDepositAwaitingConfirmation {
            let amount = proposal.depositAmountDisplay.map { " di \($0)" } ?? ""
            lines.append("Acconto\(amount): dichiarato, in attesa di conferma")
        } else {
            lines.append("Acconto: non ancora versato")
        }
        // Il numero che serve davvero il giorno dell'evento: quanto resta.
        if let due = proposal.balanceDueDisplay {
            let method = proposal.balanceMethod.map { " — \($0.shortLabel)" } ?? ""
            lines.append("Saldo da versare: \(due)\(method)")
        } else if let balance = proposal.balanceMethod {
            lines.append("Saldo: \(balance.shortLabel)")
        }
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
