# Brindoo

App iOS (SwiftUI) per organizzare feste ed eventi nel Lazio: i **clienti**
trovano professionisti e pubblicano richieste, i **professionisti**
pubblicano offerte e rispondono. Trattativa sul prezzo stile marketplace,
chat in tempo reale, recensioni verificate, agenda eventi. Backend Supabase.

## Funzioni principali

- **Bacheca doppia**: offerte dei professionisti (con filtri, ricerca,
  vetrina Boost) e richieste dei clienti (bacheca inversa, urgenti in cima)
- **Trattative**: proposta / controproposta / accettazione / ritiro della
  propria proposta (da entrambe le parti), pacchetti
  prezzo (Base/Completo/Premium), riepilogo accordo condivisibile,
  regole di annullamento mostrate prima di accettare
- **Acconto e pagamento**: si concorda come pagare (contanti o bonifico),
  chi incassa dichiara l'importo e l'altra parte conferma. I soldi non
  passano dall'app: Brindoo registra l'accordo e ne tiene traccia
- **Chat** in tempo reale: foto, risposte, modifica, bozze, risposte
  rapide, indicatore di scrittura, ricevute di lettura; i messaggi
  scritti senza linea restano in coda e partono da soli
- **Agenda**: eventi confermati, conto alla rovescia, acconto, checklist,
  promemoria locali e calendario iPhone
- **Profili**: portfolio foto, categorie, zone di copertura su mappa,
  disponibilità, FAQ, distintivi, recensioni con foto e risposta
- **Fiducia a due sensi**: recensioni "verificate" (solo dopo un evento
  davvero svolto, non al momento dell'accordo), badge "identità
  verificata" assegnato dall'amministrazione e
  distintivo di affidabilità del cliente ricavato dagli esiti degli eventi
- **Ricerche salvate**: filtri messi da parte con avviso quando compaiono
  professionisti nuovi
- **Extra**: piano Pro (StoreKit), Boost, codice invito (un mese Pro a chi
  invita e a chi accetta, assegnato dal server quando l'invitato completa
  nome, foto e descrizione), preventivo guidato,
  Live Activity per le trattative, notifiche push scegliendo le categorie
  (messaggi / trattative / promemoria)
- **Legale e GDPR**: accettazione Termini con prova sul server (data +
  versione, riproposta se i Termini cambiano), dichiarazione di
  responsabilità del professionista, esportazione dei propri dati,
  pagina diritti GDPR e guida all'uso nelle Impostazioni

## Struttura

```
Brindoo/
  App/            Ingresso app, tab bar, deep link
  DesignSystem/   Colori, font, icone, animazioni, aptica
  Features/       Schermate per area (Board, Chat, Profile, ...)
  Models/         Modelli dati (Profile, ServiceOffer, OfferProposal, ...)
  Services/       Accesso a Supabase e servizi locali
  Shared/         Componenti e logiche riusabili (BrindooFormat, badge, ...)
BrindooTests/     Test unitari su logiche pure e flussi della bacheca
supabase/         Migrazioni del database
```

## Build e test

Richiede Xcode con simulatore iOS 26.4.

```sh
xcodebuild -project Brindoo.xcodeproj -scheme Brindoo \
  -destination 'id=<UDID simulatore>' -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO

xcodebuild test -project Brindoo.xcodeproj -scheme Brindoo \
  -destination 'id=<UDID simulatore>' \
  -only-testing:BrindooTests CODE_SIGNING_ALLOWED=NO
```

## Accesso con Google

L'app apre la pagina di Google in una finestra sicura di sistema
(`ASWebAuthenticationSession`): la password la digita l'utente su Google,
Brindoo non la vede mai. Al ritorno Supabase crea o ritrova l'account con
la stessa email.

Il codice è pronto; per attivarlo servono tre passaggi **fuori dal
repository**, perche' richiedono credenziali personali:

1. **Google Cloud Console** — crea un progetto e un client OAuth di tipo
   *Web application*. Come *Authorized redirect URI* metti:
   `https://ulpuaphxdpwhyusrqqpk.supabase.co/auth/v1/callback`
2. **Supabase** — Authentication → Providers → Google: attiva il provider e
   incolla *Client ID* e *Client Secret* presi al punto 1.
3. **Supabase** — Authentication → URL Configuration → Redirect URLs:
   aggiungi `com.pasqcu.brindoo://login-callback` (lo schema e' gia'
   registrato in `Info.plist`).

Facoltativo ma consigliato: le linee guida di Google chiedono il loro logo
sul bottone. Scarica l'asset dal kit di branding ufficiale e aggiungilo
agli Asset con nome `GoogleLogo`: il bottone lo usa da solo. Senza asset
resta un segnaposto neutro, mai un'imitazione del marchio.

## Database

Migrazioni in `supabase/migrations/`, applicate al progetto prod con la
CLI `supabase db push`. Al 26 luglio 2026 sono tutte applicate, comprese
preferenze notifiche, affidabilità cliente, dettagli acconto e premio
invito. Il badge `identity_verified` sui profili si
assegna solo dalla dashboard Supabase (un trigger blocca l'auto-assegnazione
via API).

La scadenza del piano Pro (`pro_expires_at`) resta scrivibile solo dal
ruolo di servizio. Il premio invito fa eccezione tramite un contrassegno
valido per la sola transazione, alzato unicamente dalle funzioni del
server: i client passano dall'API e non possono alzarlo.
