//
//  AppGuideView.swift
//  Brindoo
//
//  Guida all'uso dell'app, scheda per scheda, divisa per ruolo.
//  Statica: niente server, solo istruzioni chiare.
//

import SwiftUI

struct AppGuideView: View {

    @Environment(SessionStore.self) private var session

    private var isOrganizer: Bool {
        session.currentProfile?.role == .organizer
    }

    private struct Step: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let text: String
    }

    private var clientSteps: [Step] {
        [
            Step(icon: "magnifyingglass", title: "Esplora",
                 text: "Sfoglia i professionisti del Lazio. Filtra per servizio, zona, prezzo, valutazione o data dell'evento. Tocca la bacchetta magica per il preventivo guidato: categoria + data + budget e vedi subito le offerte adatte."),
            Step(icon: "megaphone", title: "Pubblica una richiesta",
                 text: "Non trovi quello che cerchi? Tocca il megafono e racconta cosa ti serve: saranno i professionisti a contattarti. Se l'evento è vicino, segnala la richiesta come urgente."),
            Step(icon: "arrow.left.arrow.right", title: "Trattative",
                 text: "Su un'offerta puoi accettare il prezzo, scegliere un pacchetto (Base/Completo/Premium) o fare una proposta. Prima di accettare leggi le regole di annullamento. Ad accordo chiuso puoi condividere il riepilogo scritto."),
            Step(icon: "bubble.left.and.bubble.right", title: "Chat",
                 text: "Scrivi ai professionisti per definire i dettagli: orari, luogo, extra. Puoi inviare foto, rispondere a un messaggio specifico e modificare i tuoi messaggi appena inviati."),
            Step(icon: "calendar", title: "Agenda",
                 text: "Gli eventi confermati finiscono in agenda con conto alla rovescia. Tocca ⋯ su un evento per segnare l'acconto versato o aprire la checklist dei preparativi."),
            Step(icon: "star", title: "Recensioni",
                 text: "A evento svolto, lascia una recensione (anche con foto). Solo chi ha davvero concluso una trattativa può recensire: per questo trovi il contrassegno «Verificata»."),
            Step(icon: "heart", title: "Preferiti e confronto",
                 text: "Salva i profili che ti piacciono col cuore. Dai preferiti puoi confrontarne 2-3 fianco a fianco: valutazione, velocità di risposta, identità verificata, prezzo di partenza.")
        ]
    }

    private var organizerSteps: [Step] {
        [
            Step(icon: "list.bullet.rectangle", title: "Bacheca",
                 text: "Le tue offerte pubblicate. Tocca + per crearne una nuova; tieni premuta un'offerta per duplicarla. Ogni offerta può avere fino a 3 pacchetti prezzo (Base/Completo/Premium)."),
            Step(icon: "megaphone", title: "Richieste dei clienti",
                 text: "Tocca il megafono per sfogliare cosa cercano i clienti (le urgenti sono in cima). Rispondi in chat a quelle adatte a te."),
            Step(icon: "arrow.left.arrow.right", title: "Trattative",
                 text: "Quando un cliente accetta o propone un prezzo, rispondi qui: accetta, rifiuta o controproponi. Ad accordo chiuso trovi il riepilogo condivisibile e lo stato dell'acconto."),
            Step(icon: "person.crop.circle", title: "Profilo curato = più clienti",
                 text: "Foto profilo, bio, categorie, portfolio (almeno 3 foto), zone di copertura e 2-3 domande frequenti: la barra «profilo completo» ti guida. I profili curati compaiono più in alto."),
            Step(icon: "calendar", title: "Disponibilità e agenda",
                 text: "Segna i giorni in cui non sei disponibile: i clienti li vedono sul tuo profilo e il preventivo guidato ti esclude quando sei occupato. Gli eventi confermati sono in agenda con acconto e checklist."),
            Step(icon: "crown", title: "Pro e Boost",
                 text: "Con Brindoo Pro hai offerte illimitate, statistiche, modalità vacanza e priorità in bacheca. Il Boost ti mette in vetrina «In evidenza» per un periodo."),
            Step(icon: "person.badge.shield.checkmark", title: "Identità verificata",
                 text: "Il badge blu è assegnato dal team di Brindoo dopo un controllo. Contattaci dall'assistenza per richiederlo.")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                section(title: isOrganizer ? "Per te (professionista)" : "Per te (cliente)",
                        steps: isOrganizer ? organizerSteps : clientSteps)
                section(title: isOrganizer ? "Come la vive il cliente" : "Come la vive il professionista",
                        steps: isOrganizer ? clientSteps : organizerSteps)
            }
            .padding(BrindooSpacing.md)
        }
        .background(Color.brindooBackground)
        .navigationTitle("Guida all'app")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(title: String, steps: [Step]) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            Text(title)
                .font(BrindooFont.titleSmall)

            ForEach(steps) { step in
                HStack(alignment: .top, spacing: BrindooSpacing.sm) {
                    Image(systemName: step.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.brindooCoral)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(BrindooFont.bodyMedium.weight(.semibold))
                        Text(step.text)
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
        }
    }
}
