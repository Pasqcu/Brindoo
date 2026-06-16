//
//  PrivacyPolicyView.swift
//  Brindoo
//
//  Informativa Privacy in conformità a GDPR Art. 13 e App Store Guideline 5.1.1.
//  Il testo è strutturato per coprire tutti i punti obbligatori:
//   - identità del Titolare
//   - tipologie di dati trattati
//   - finalità e basi giuridiche
//   - destinatari e trasferimenti
//   - tempi di conservazione
//   - diritti dell'interessato e diritto di reclamo al Garante
//

import SwiftUI

struct PrivacyPolicyView: View {

    /// Ultimo aggiornamento sostanziale del testo. Va incrementato a ogni modifica:
    /// la PP deve avere una data fissa, NON la data corrente (sennò "ultimo aggiornamento"
    /// cambia ogni giorno e perde significato legale).
    private let lastUpdate = "15 maggio 2026"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

                Text("Privacy Policy")
                    .font(BrindooFont.displayMedium)

                Text("Ultimo aggiornamento: \(lastUpdate)")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)

                Group {
                    section(
                        title: "1. Titolare del Trattamento",
                        body: """
Titolare del trattamento dei dati personali è:

Pasquale Aceto
Email: pasqcu.app.support@gmail.com

In assenza di un Responsabile della Protezione dei Dati (DPO), per qualsiasi richiesta in materia di privacy puoi scrivere all'indirizzo email indicato.
"""
                    )

                    section(
                        title: "2. Tipologie di dati trattati",
                        body: """
Brindoo tratta le seguenti categorie di dati personali:

a) Dati di registrazione
• Email
• Password (memorizzata cifrata con bcrypt, mai accessibile in chiaro nemmeno al Titolare)
• Identificativo Apple Sign In (se scegli di registrarti con Apple)

b) Dati di profilo
• Nome o nome attività
• Città
• Numero di telefono (facoltativo)
• Bio (facoltativa)
• Foto profilo (facoltativa)
• Ruolo: Cliente o Organizzatore

c) Dati di portfolio (solo Organizzatori)
• Foto del portfolio
• Categorie di servizi offerti
• Descrizioni dei servizi

d) Dati di interazione
• Offerte di servizio pubblicate e trattative (proposte e controproposte)
• Conversazioni, messaggi e relativi allegati
• Recensioni rilasciate o ricevute
• Lista degli utenti bloccati

e) Dati tecnici e di utilizzo
• Identificativo univoco utente (UUID)
• Token notifiche push (APNs)
• Visualizzazioni di profili e offerte (mostrate all'organizzatore Pro come statistica)
• Stato della tua sottoscrizione Pro e degli acquisti Boost
• Identificativo transazione StoreKit (per anti-frode)

f) Dati che NON raccogliamo
• Geolocalizzazione GPS precisa
• Dati biometrici, sanitari, di orientamento o categorie particolari (Art. 9 GDPR)
• Dati di tracciamento per pubblicità su altre app (no SDK Meta/Google/etc.)
"""
                    )

                    section(
                        title: "3. Finalità e basi giuridiche del trattamento",
                        body: """
I tuoi dati sono trattati per le finalità e con le basi giuridiche seguenti:

• Erogazione del servizio (creazione e gestione del tuo account, profilo, offerte, trattative, chat, recensioni) — base giuridica: esecuzione del contratto con l'utente (Art. 6.1.b GDPR).

• Sicurezza, prevenzione frodi e moderazione dei contenuti — base giuridica: legittimo interesse (Art. 6.1.f GDPR) a proteggere gli utenti e l'integrità della piattaforma.

• Statistiche interne all'app (visite profilo e offerte mostrate agli Organizzatori Pro) — base giuridica: legittimo interesse (Art. 6.1.f GDPR) limitato a dati aggregati e funzionali al servizio.

• Notifiche push relative all'attività dell'app (nuovi messaggi, trattative) — base giuridica: consenso esplicito conferito tramite il prompt iOS al primo accesso (Art. 6.1.a GDPR). Puoi revocarlo in qualsiasi momento da Impostazioni iOS.

• Gestione degli acquisti in-app — base giuridica: esecuzione del contratto (Art. 6.1.b GDPR) e obbligo di legge in materia fiscale (Art. 6.1.c GDPR).

• Adempimenti legali in caso di richieste delle autorità — base giuridica: obbligo di legge (Art. 6.1.c GDPR).
"""
                    )

                    section(
                        title: "4. Destinatari dei dati",
                        body: """
I tuoi dati sono accessibili esclusivamente:

• Al Titolare, per le finalità sopra indicate
• Agli altri utenti di Brindoo, limitatamente ai dati che tu rendi pubblici (profilo, portfolio, recensioni, città, bio)
• Ai seguenti fornitori esterni che agiscono come Responsabili del Trattamento ai sensi dell'Art. 28 GDPR:

  – Supabase Inc., per l'infrastruttura di database, autenticazione e storage. I server sono nell'Unione Europea (regione "eu-west" o equivalente). Privacy policy: https://supabase.com/privacy

  – Apple Inc., per (i) le notifiche push tramite APNs, (ii) gli acquisti in-app via StoreKit, (iii) facoltativamente l'autenticazione Sign in with Apple. Apple opera anche fuori dall'UE: in tal caso il trasferimento è basato sulle Clausole Contrattuali Standard approvate dalla Commissione Europea. Privacy policy: https://www.apple.com/legal/privacy/

I tuoi dati NON sono ceduti, venduti o concessi a terze parti per finalità di marketing, profilazione pubblicitaria o data brokerage.
"""
                    )

                    section(
                        title: "5. Trasferimenti extra-UE",
                        body: """
I dati personali sono conservati primariamente in server situati nell'Unione Europea. Alcuni servizi tecnici (in particolare le notifiche push gestite da Apple/APNs) possono comportare il trasferimento di un identificativo tecnico (device token) verso server Apple ubicati negli Stati Uniti. Tale trasferimento avviene sulla base delle Clausole Contrattuali Standard approvate dalla Commissione Europea (Decisione 2021/914) e delle ulteriori misure tecniche e organizzative implementate da Apple Inc.
"""
                    )

                    section(
                        title: "6. Tempi di conservazione",
                        body: """
I dati sono conservati per i periodi seguenti:

• Dati account e profilo: per tutta la durata dell'account. Cancellando l'account dall'app i dati sono eliminati in modo permanente entro 24 ore.

• Conversazioni e messaggi: per tutta la durata dell'account o fino a quando uno dei due partecipanti elimina la conversazione.

• Recensioni rilasciate: per tutta la durata del tuo account; alla cancellazione vengono rimosse anche le recensioni che hai scritto.

• Dati relativi agli acquisti in-app: 10 anni dalla data di acquisto per adempiere agli obblighi fiscali e di prova della transazione (Art. 2220 c.c.).

• Log tecnici di sicurezza (autenticazione, IP delle ultime sessioni): massimo 30 giorni.

• Segnalazioni inviate al team di moderazione: fino a 12 mesi dopo la risoluzione, per gestione di abusi reiterati.

• Token notifiche push: rimossi automaticamente al logout o disinstallazione dell'app.
"""
                    )

                    section(
                        title: "7. I tuoi diritti",
                        body: """
In conformità agli articoli 15-22 del GDPR hai diritto a:

• Accesso (Art. 15) — visualizzare i dati che ti riguardano dalle sezioni Profilo e Impostazioni dell'app.
• Rettifica (Art. 16) — modificare i tuoi dati dalla sezione Modifica profilo.
• Cancellazione / oblio (Art. 17) — eliminare definitivamente l'account da Impostazioni → Elimina account.
• Limitazione del trattamento (Art. 18) — scrivere all'indirizzo email del Titolare.
• Portabilità (Art. 20) — richiedere via email una copia in formato JSON dei tuoi dati.
• Opposizione (Art. 21) — chiudere l'account o disattivare le notifiche push dalle Impostazioni iOS.
• Revoca del consenso (Art. 7) — per i trattamenti basati sul consenso, in qualsiasi momento e senza pregiudizio per la liceità del trattamento precedente.

Per esercitare i tuoi diritti scrivi a: pasqcu.app.support@gmail.com. Risponderemo entro 30 giorni.
"""
                    )

                    section(
                        title: "8. Diritto di reclamo all'Autorità di controllo",
                        body: """
Se ritieni che il trattamento dei tuoi dati violi il GDPR, hai diritto di proporre reclamo all'Autorità Garante per la Protezione dei Dati Personali italiana:

Garante per la protezione dei dati personali
Piazza Venezia n. 11 — 00187 Roma
Email: protocollo@gpdp.it
PEC: protocollo@pec.gpdp.it
Sito: www.garanteprivacy.it

Puoi inoltre rivolgerti all'autorità di controllo del Paese UE in cui risiedi abitualmente.
"""
                    )

                    section(
                        title: "9. Sicurezza dei dati",
                        body: """
Adottiamo misure tecniche e organizzative adeguate per proteggere i tuoi dati:

• Le password sono memorizzate con hash bcrypt salt-per-utente (non sono mai accessibili in chiaro).
• Tutte le comunicazioni tra l'app e i server avvengono via HTTPS / TLS 1.2+.
• L'accesso ai dati è regolato da policy di Row Level Security (RLS) a livello database: ogni utente può accedere solo ai propri dati e a quelli pubblici degli altri utenti.
• Le foto bomba della chat sono cancellate dallo storage dopo essere state aperte dal destinatario.
• In caso di data breach con rischio elevato per i tuoi diritti, ti informeremo entro 72 ore ai sensi dell'Art. 34 GDPR.
"""
                    )

                    section(
                        title: "10. Età minima e minori",
                        body: """
Brindoo è destinata esclusivamente a utenti che abbiano compiuto 18 anni. All'iscrizione confermerai di avere l'età richiesta. Se veniamo a conoscenza che un account è stato creato da un minore di 18 anni provvederemo a chiuderlo e a cancellarne tutti i dati. Se sei genitore o tutore e ritieni che un minore abbia creato un account, scrivici a pasqcu.app.support@gmail.com per la rimozione immediata.
"""
                    )

                    section(
                        title: "11. Cookie e tecnologie analoghe",
                        body: "L'app Brindoo non utilizza cookie. Non integriamo SDK di tracciamento di terze parti per pubblicità o analytics esterni (es. Google Analytics, Meta SDK, Mixpanel, Firebase Analytics). Le statistiche di utilizzo mostrate agli Organizzatori Pro sono calcolate esclusivamente sui dati interni della piattaforma."
                    )

                    section(
                        title: "12. Modifiche all'informativa",
                        body: "Possiamo aggiornare questa Privacy Policy per riflettere modifiche al servizio o alla normativa. Le modifiche significative ti saranno comunicate in-app o via email almeno 7 giorni prima dell'entrata in vigore. La data dell'ultimo aggiornamento è indicata in cima al documento."
                    )

                    section(
                        title: "13. Contatti",
                        body: """
Per qualsiasi domanda, richiesta o reclamo relativi alla privacy:

Email: pasqcu.app.support@gmail.com

Risponderemo entro 30 giorni dalla ricezione della richiesta.
"""
                    )
                }
            }
            .padding(BrindooSpacing.lg)
            .padding(.bottom, BrindooSpacing.xl)
        }
        .background(Color.brindooBackground)
        .navigationTitle("Privacy")
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
