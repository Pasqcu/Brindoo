# Brindoo

App iOS (SwiftUI) per organizzare feste ed eventi nel Lazio: i **clienti**
trovano professionisti e pubblicano richieste, i **professionisti**
pubblicano offerte e rispondono. Trattativa sul prezzo stile marketplace,
chat in tempo reale, recensioni verificate, agenda eventi. Backend Supabase.

## Funzioni principali

- **Bacheca doppia**: offerte dei professionisti (con filtri, ricerca,
  vetrina Boost) e richieste dei clienti (bacheca inversa, urgenti in cima)
- **Trattative**: proposta / controproposta / accettazione, pacchetti
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
- **Fiducia a due sensi**: recensioni "verificate" (solo da trattative
  concluse), badge "identità verificata" assegnato dall'amministrazione e
  distintivo di affidabilità del cliente ricavato dagli esiti degli eventi
- **Ricerche salvate**: filtri messi da parte con avviso quando compaiono
  professionisti nuovi
- **Extra**: piano Pro (StoreKit), Boost, referral, preventivo guidato,
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

## Database

Migrazioni in `supabase/migrations/`, applicate al progetto prod con la
CLI `supabase db push`. Le ultime due (preferenze notifiche + affidabilità
cliente, dettagli acconto) vanno applicate perché le relative schermate
funzionino: senza, l'app continua a partire e usa i valori di partenza. Il badge `identity_verified` sui profili si
assegna solo dalla dashboard Supabase (un trigger blocca l'auto-assegnazione
via API).
