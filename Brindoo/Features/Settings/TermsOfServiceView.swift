//
//  TermsOfServiceView.swift
//  Brindoo
//
//  Termini di Servizio (EULA) in conformità a:
//  - App Store Guideline 1.2 (User-Generated Content): tolleranza zero per
//    contenuti offensivi, meccanismo di segnalazione, blocco utenti, risposta 24h.
//  - App Store Guideline 3.1.2 (Subscriptions): disclosure rinnovo automatico.
//  - App Store Guideline 5.1.1 (Account Deletion).
//  - Codice del Consumo italiano (D.Lgs. 206/2005).
//

import SwiftUI

struct TermsOfServiceView: View {

    /// Data fissa dell'ultimo aggiornamento. NON usare Date() dinamica.
    private let lastUpdate = "15 maggio 2026"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

                Text("Termini di Servizio")
                    .font(BrindooFont.displayMedium)

                Text("Ultimo aggiornamento: \(lastUpdate)")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)

                Group {
                    section(
                        title: "1. Accettazione dei termini",
                        body: "Utilizzando l'applicazione Brindoo (\"Brindoo\", \"l'App\" o \"il Servizio\") accetti integralmente i presenti Termini di Servizio (\"Termini\") e l'allegata Privacy Policy. Se non sei d'accordo con anche solo una parte dei Termini, non puoi usare Brindoo. L'accettazione avviene al momento dell'iscrizione tramite l'apposito flag e ogni successivo accesso conferma la tua accettazione delle eventuali modifiche."
                    )

                    section(
                        title: "2. Descrizione del servizio",
                        body: "Brindoo è una piattaforma che mette in contatto clienti (\"Cliente\") e professionisti dell'organizzazione di feste ed eventi (\"Organizzatore\"): animatori, fotografi, catering, location, e simili. Brindoo facilita esclusivamente l'incontro tra domanda e offerta. Non è parte degli accordi commerciali eventualmente conclusi tra Cliente e Organizzatore, né si configura come agenzia, intermediario, datore di lavoro, mandatario o garante delle prestazioni."
                    )

                    section(
                        title: "3. Età minima ed eleggibilità",
                        body: """
Per usare Brindoo devi:

• avere almeno 18 anni di età (o l'età della maggiore età secondo la legge del tuo Paese di residenza, se superiore);
• avere la piena capacità di agire ai sensi della normativa applicabile;
• non essere stato precedentemente sospeso o bannato dal Servizio.

Al momento dell'iscrizione confermerai esplicitamente di soddisfare questi requisiti. La creazione di account da parte di minori comporta la chiusura immediata e la cancellazione di tutti i dati.
"""
                    )

                    section(
                        title: "4. Account utente",
                        body: """
• Sei responsabile della custodia delle credenziali di accesso. Scegli una password robusta (almeno 8 caratteri, un numero e un carattere speciale) e non condividerla.
• I dati che inserisci nel profilo (nome, città, telefono, bio, foto) devono essere veri, aggiornati e di tua titolarità. Profili falsi, profili impersonificanti terzi o profili creati per scopi fraudolenti saranno rimossi.
• Puoi avere un solo account. Multi-accounting (più account per la stessa persona fisica) è vietato e può portare alla sospensione di tutti gli account collegati.
• Sei l'unico responsabile delle attività compiute sotto il tuo account. Informa immediatamente il Titolare in caso di accesso non autorizzato o smarrimento delle credenziali.
"""
                    )

                    section(
                        title: "5. Contenuti generati dall'utente (UGC)",
                        body: """
Caricando contenuti su Brindoo (foto profilo, foto portfolio, descrizioni, messaggi, recensioni, richieste, offerte) garantisci di:

• essere il titolare dei diritti su tali contenuti, o di avere ottenuto tutte le necessarie autorizzazioni (incluso il consenso di eventuali persone ritratte nelle foto);
• non violare diritti di terzi, marchi, copyright, segreti industriali, diritti della personalità o normative applicabili.

Concedi a Brindoo una licenza non esclusiva, gratuita, valida nel mondo intero e limitata alle sole finalità del Servizio, per ospitare, mostrare, ridimensionare, comprimere e distribuire i tuoi contenuti agli altri utenti della piattaforma e nei materiali tecnici necessari al funzionamento dell'App. La proprietà intellettuale dei contenuti resta tua. La licenza cessa con la cancellazione del contenuto o dell'account.
"""
                    )

                    section(
                        title: "6. Tolleranza zero per contenuti e comportamenti abusivi",
                        body: """
Brindoo applica una politica di TOLLERANZA ZERO per contenuti illeciti e comportamenti abusivi. È espressamente VIETATO pubblicare o trasmettere:

• Contenuti illegali, diffamatori, calunniosi, minatori, discriminatori (razza, etnia, religione, genere, orientamento, disabilità), incitamento all'odio o alla violenza.
• Contenuti sessualmente espliciti, pornografici, di nudo non artistico o pedopornografici.
• Molestie, stalking, bullismo, doxxing o pubblicazione di informazioni personali altrui senza consenso.
• Contenuti che violano la proprietà intellettuale altrui (immagini, testi, marchi).
• Spam, schemi piramidali, phishing, scraping automatizzato, tentativi di compromettere la sicurezza della piattaforma.
• Promozione o organizzazione di attività illegali, riciclaggio, frodi, evasione fiscale.
• Bypass della piattaforma per evitare le commissioni o le funzionalità premium (quando applicabili).
• Recensioni false, coordinate, comprate o pubblicate per ricatto/ritorsione.
• Creazione o partecipazione a gruppi di utenti coordinati per manipolare la reputazione altrui.

Le violazioni comportano la rimozione del contenuto, la sospensione e in casi gravi la chiusura definitiva dell'account, l'eliminazione di tutti i dati e, ove necessario, la segnalazione alle autorità competenti.
"""
                    )

                    section(
                        title: "7. Segnalazione di contenuti e utenti",
                        body: """
Se incontri contenuti o comportamenti che violano questi Termini, puoi e devi segnalarli:

• Direttamente in-app, dal menu "Segnala" presente accanto a ogni utente, recensione, messaggio, foto del portfolio e offerta.
• Via email all'indirizzo pasqcu.app.support@gmail.com indicando il link al contenuto e il motivo.

Il team di moderazione esamina ogni segnalazione e risponde entro 24 ore con un'azione (rimozione del contenuto, avvertimento, sospensione dell'utente, o respinta motivata). Le segnalazioni sono trattate in modo confidenziale: l'utente segnalato non viene a conoscenza di chi lo ha segnalato.

Puoi inoltre BLOCCARE qualsiasi utente da Impostazioni → Utenti bloccati o dalla chat. Gli utenti bloccati non potranno più contattarti né vedere il tuo profilo, e tu non vedrai i loro contenuti.
"""
                    )

                    section(
                        title: "8. Transazioni tra Cliente e Organizzatore",
                        body: """
Brindoo facilita il contatto tra Cliente e Organizzatore, ma non gestisce direttamente i pagamenti relativi ai servizi concordati offline (a eccezione delle proprie funzionalità a pagamento, vedi punto 9).

Termini economici, modalità di pagamento, fatturazione, eventuali contratti, cancellazioni e rimborsi sono accordi diretti e privati tra Cliente e Organizzatore.

Brindoo non è responsabile per:
• la qualità, la puntualità o la conformità del servizio prestato dall'Organizzatore;
• il mancato pagamento da parte del Cliente;
• danni patrimoniali o non patrimoniali derivanti dall'esecuzione (o mancata esecuzione) delle prestazioni concordate;
• controversie tra le parti.

Restano salvi i diritti del Cliente e dell'Organizzatore previsti dalla normativa applicabile, da far valere direttamente nei confronti dell'altra parte.
"""
                    )

                    section(
                        title: "9. Abbonamento Brindoo Pro e acquisti Boost",
                        body: """
Brindoo offre funzionalità a pagamento tramite il sistema di Acquisti In-App di Apple (StoreKit):

• Brindoo Pro Mensile — abbonamento auto-rinnovabile a €3,99 al mese (prezzo indicativo, quello effettivo è mostrato in app al momento dell'acquisto secondo il listino App Store del tuo Paese).
  – Il pagamento è addebitato sul tuo account Apple alla conferma.
  – Il rinnovo automatico avviene 24 ore prima della scadenza dell'attuale periodo, salvo disattivazione almeno 24 ore prima della scadenza nelle impostazioni del tuo account Apple (Impostazioni → [Tuo nome] → Abbonamenti).
  – Le porzioni inutilizzate di periodi gratuiti, ove disponibili, decadono al primo acquisto.
  – Eventuali rimborsi sono gestiti esclusivamente da Apple secondo le sue policy: reportaproblem.apple.com.

• Boost 1 giorno e Boost 1 settimana — acquisti singoli consumabili, senza rinnovo automatico. Si attivano subito dopo l'acquisto per la durata indicata.

Il bottone "Ripristina acquisti" nella schermata Pro consente di recuperare gli abbonamenti attivi dopo un cambio dispositivo o una reinstallazione.

Tutte le verifiche di transazione sono effettuate lato server con la chiave pubblica Apple per prevenire frodi.
"""
                    )

                    section(
                        title: "10. Diritto di recesso (consumatori UE)",
                        body: """
Ai sensi degli artt. 52-59 del Codice del Consumo (D.Lgs. 206/2005), in caso di acquisto di servizi digitali a distanza il consumatore ha diritto di recesso entro 14 giorni dalla conclusione del contratto.

ATTENZIONE: l'acquisto e l'attivazione immediata di un abbonamento Brindoo Pro o di un Boost configurano l'esecuzione di un servizio digitale richiesta dal consumatore. Confermando l'acquisto in App Store accetti espressamente l'esecuzione immediata e prendi atto che, ai sensi dell'art. 59, comma 1, lett. o) del Codice del Consumo, il diritto di recesso decade una volta iniziata l'esecuzione.

Per eventuali rimborsi puoi comunque rivolgerti direttamente ad Apple tramite reportaproblem.apple.com: il rimborso, se concesso, sarà gestito da Apple secondo le sue policy.
"""
                    )

                    section(
                        title: "11. Recensioni",
                        body: """
Le recensioni devono riflettere esperienze reali e in buona fede dell'utente. È vietato:

• pubblicare recensioni false, diffamatorie, ricattatorie o coordinate;
• minacciare di pubblicare una recensione negativa per ottenere sconti o vantaggi;
• premere su un cliente affinché modifichi o ritiri una recensione.

Brindoo si riserva il diritto di rimuovere recensioni in violazione di queste regole e di sospendere gli account responsabili. Una recensione contestata può essere segnalata dal soggetto recensito; il team valuterà entro 24 ore se rimuoverla o mantenerla.
"""
                    )

                    section(
                        title: "12. Disponibilità del servizio e limitazione di responsabilità",
                        body: """
Brindoo è fornito \"così com'è\" e \"come disponibile\". Nei limiti consentiti dalla legge:

• Non garantiamo continuità ininterrotta o assenza di errori del Servizio.
• Possiamo eseguire manutenzioni programmate o straordinarie.
• Non siamo responsabili per danni indiretti, consequenziali, perdita di profitti, perdita di dati o perdita di opportunità derivanti dall'uso (o dall'impossibilità di uso) dell'App, salvo i casi di dolo o colpa grave.

Restano salvi i diritti inderogabili spettanti al consumatore ai sensi della normativa applicabile.
"""
                    )

                    section(
                        title: "13. Modifiche ai Termini e al Servizio",
                        body: "Possiamo aggiornare l'App, le sue funzionalità o interrompere il Servizio in qualsiasi momento. Le modifiche significative a questi Termini ti saranno comunicate in-app o via email almeno 7 giorni prima dell'entrata in vigore. L'uso continuato dell'App dopo l'entrata in vigore costituisce accettazione delle nuove condizioni. Se non accetti le modifiche puoi eliminare l'account in qualsiasi momento."
                    )

                    section(
                        title: "14. Sospensione e chiusura dell'account",
                        body: """
Brindoo può sospendere o chiudere l'account in caso di:
• violazione di questi Termini, in particolare del punto 6;
• segnalazioni reiterate confermate dalla moderazione;
• attività fraudolenta o tentativi di compromissione della sicurezza;
• richieste delle autorità competenti.

L'utente può eliminare il proprio account in qualsiasi momento da Impostazioni → Elimina account. La cancellazione è definitiva e comporta la rimozione di tutti i dati associati entro 24 ore (salvo i dati che devono essere conservati per obblighi di legge: vedi Privacy Policy).
"""
                    )

                    section(
                        title: "15. Legge applicabile e foro competente",
                        body: """
Questi Termini sono regolati dalla legge italiana. Per ogni controversia con un consumatore è competente il foro del luogo di residenza o domicilio del consumatore, se ubicato in Italia, ai sensi dell'art. 66-bis del Codice del Consumo.

In via preventiva alla via giudiziale, il consumatore può ricorrere alla piattaforma europea di Risoluzione Online delle Controversie (ODR): https://ec.europa.eu/consumers/odr.
"""
                    )

                    section(
                        title: "16. Disposizioni finali",
                        body: """
• Se una clausola dei Termini risulta invalida o inapplicabile, le restanti continuano a valere.
• Il mancato esercizio di un diritto da parte di Brindoo non costituisce rinuncia a tale diritto.
• I Termini sono redatti in italiano. In caso di traduzioni la versione italiana prevale.
"""
                    )

                    section(
                        title: "17. Contatti e supporto",
                        body: """
Per qualsiasi richiesta relativa a questi Termini, al Servizio o alla moderazione dei contenuti:

Email: pasqcu.app.support@gmail.com

Il team di moderazione risponde entro 24 ore alle segnalazioni di contenuti.
Il supporto generico risponde entro 5 giorni lavorativi.
"""
                    )
                }
            }
            .padding(BrindooSpacing.lg)
            .padding(.bottom, BrindooSpacing.xl)
        }
        .background(Color.brindooBackground)
        .navigationTitle("Termini")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text(title)
                .font(BrindooFont.titleMedium)
                .padding(.top, BrindooSpacing.sm)

            Text(body)
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
