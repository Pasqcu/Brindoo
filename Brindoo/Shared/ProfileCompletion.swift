//
//  ProfileCompletion.swift
//  Brindoo
//
//  Calcola quanto è "curato" il profilo di un professionista (0–100)
//  e suggerisce il prossimo passo per completarlo. Logica pura + card UI.
//

import SwiftUI

// MARK: - Logica (testabile)

struct ProfileCompletion: Equatable {

    /// Un tassello del profilo, con il suo peso e il suggerimento da mostrare.
    struct Item: Equatable {
        let done: Bool
        let weight: Int
        let suggestion: String
    }

    let items: [Item]

    /// Punteggio 0–100.
    var score: Int {
        let total = items.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return 100 }
        let done = items.filter(\.done).reduce(0) { $0 + $1.weight }
        return Int((Double(done) / Double(total) * 100).rounded())
    }

    var isComplete: Bool { score >= 100 }

    /// Il primo suggerimento utile (l'azione con più peso ancora da fare).
    var nextSuggestion: String? {
        items.filter { !$0.done }.max(by: { $0.weight < $1.weight })?.suggestion
    }

    /// Valuta il profilo di un professionista.
    static func evaluate(
        hasAvatar: Bool,
        bioLength: Int,
        categoriesCount: Int,
        portfolioCount: Int,
        activeOffersCount: Int,
        coverageAreasCount: Int,
        faqsCount: Int = 0
    ) -> ProfileCompletion {
        ProfileCompletion(items: [
            Item(done: hasAvatar, weight: 15,
                 suggestion: "Aggiungi una foto profilo: i clienti si fidano di chi ci mette la faccia"),
            Item(done: bioLength >= 30, weight: 15,
                 suggestion: "Racconta chi sei in due righe nella sezione \"Chi sono\""),
            Item(done: categoriesCount > 0, weight: 20,
                 suggestion: "Scegli le categorie dei tuoi servizi per farti trovare"),
            Item(done: portfolioCount >= 3, weight: 20,
                 suggestion: "Carica almeno 3 foto nel portfolio dei tuoi lavori"),
            Item(done: activeOffersCount > 0, weight: 20,
                 suggestion: "Pubblica la tua prima offerta in bacheca"),
            Item(done: coverageAreasCount > 0, weight: 10,
                 suggestion: "Indica le zone del Lazio in cui lavori"),
            Item(done: faqsCount > 0, weight: 10,
                 suggestion: "Aggiungi 2-3 domande frequenti: meno domande ripetitive in chat")
        ])
    }
}

// MARK: - Card "Profilo completo al X%"

struct ProfileCompletionCard: View {

    let completion: ProfileCompletion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: BrindooSpacing.md) {
                ZStack {
                    Circle()
                        .stroke(Color.brindooCoral.opacity(0.15), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: CGFloat(completion.score) / 100)
                        .stroke(Color.brindooCoral, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(completion.score)%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.brindooCoral)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Profilo completo al \(completion.score)%")
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                    if let suggestion = completion.nextSuggestion {
                        Text(suggestion)
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooTextSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooCoral.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: BrindooRadius.md)
                    .strokeBorder(Color.brindooCoral.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profilo completo al \(completion.score) per cento. \(completion.nextSuggestion ?? "")")
    }
}
