//
//  HelpView.swift
//  Brindoo
//
//  Domande frequenti e contatti. Brindoo è attivo nella regione Lazio.
//

import SwiftUI

struct HelpView: View {

    private struct FAQ: Identifiable {
        let id = UUID()
        let q: String
        let a: String
    }

    private let faqs: [FAQ] = [
        FAQ(q: "Cos'è Brindoo?",
            a: "Brindoo mette in contatto chi organizza feste ed eventi con i professionisti giusti (animatori, fotografi, catering, location e altro). È attivo in tutta la regione Lazio."),
        FAQ(q: "Come trovo un professionista?",
            a: "Vai su Esplora, filtra per servizio, zona, prezzo o valutazione, apri un profilo e invia un messaggio o una proposta."),
        FAQ(q: "Come funziona la trattativa?",
            a: "Sull'offerta puoi accettare il prezzo o fare una proposta. Il professionista può accettare, rifiutare o fare una controproposta. Quando vi accordate, l'appuntamento è confermato."),
        FAQ(q: "Le recensioni sono affidabili?",
            a: "Sì: si può recensire solo dopo una trattativa realmente conclusa. Le recensioni verificate hanno un apposito contrassegno."),
        FAQ(q: "Come divento professionista?",
            a: "Dal tuo profilo tocca «Diventa Professionista», completa categorie, descrizione e aree di copertura, poi pubblica la tua prima offerta."),
        FAQ(q: "Cos'è Brindoo Pro?",
            a: "È l'abbonamento per i professionisti: offerte illimitate, priorità in bacheca, statistiche, modalità vacanza e portfolio ampliato."),
        FAQ(q: "Come segnalo un utente o un contenuto?",
            a: "Apri il profilo, l'offerta o la chat, tocca il menu «…» e scegli «Segnala». Le segnalazioni vengono esaminate dal nostro team.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.md) {
                ForEach(faqs) { faq in
                    DisclosureGroup {
                        Text(faq.a)
                            .font(BrindooFont.bodyMedium)
                            .foregroundStyle(Color.brindooTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, BrindooSpacing.xs)
                    } label: {
                        Text(faq.q)
                            .font(BrindooFont.bodyLarge.weight(.semibold))
                            .foregroundStyle(Color.brindooTextPrimary)
                    }
                    .tint(Color.brindooCoral)
                    .padding(BrindooSpacing.md)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                }

                if let url = URL(string: "mailto:supporto@brindoo.app?subject=Assistenza%20Brindoo") {
                    Link(destination: url) {
                        HStack(spacing: BrindooSpacing.sm) {
                            Image(systemName: "envelope.fill")
                            Text("Non hai trovato risposta? Scrivici")
                                .font(BrindooFont.bodyMedium.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color.brindooCoral)
                        .padding(BrindooSpacing.md)
                        .background(Color.brindooCoral.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    }
                }
            }
            .padding(BrindooSpacing.md)
            .brindooReadableWidth()
        }
        .background(Color.brindooBackground)
        .navigationTitle("Aiuto")
        .navigationBarTitleDisplayMode(.inline)
    }
}
