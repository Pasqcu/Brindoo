# Brindoo Live Activity

Questa cartella contiene il codice del Widget Extension per le Live Activity di Brindoo. **I file qui dentro NON fanno parte del target principale**: vanno spostati in un nuovo Widget Extension target che dovrai creare in Xcode.

## Cosa è già pronto nell'app principale

- `Brindoo/LiveActivities/NegotiationActivityAttributes.swift` — schema condiviso (Attributes + ContentState).
- `Brindoo/LiveActivities/LiveActivityManager.swift` — helper per start / update / end.
- `Brindoo/Info.plist` — flag `NSSupportsLiveActivities = true`.

## Cosa devi fare in Xcode

1. **Apri il progetto in Xcode** (`Brindoo.xcodeproj`).
2. **Crea il Widget Extension target**:
   - `File → New → Target...`
   - Seleziona **Widget Extension** (iOS).
   - Product name: `BrindooLiveActivity`.
   - Bundle ID consigliato: `com.pasqcu.brindoo.liveactivity` (deve essere prefissato da quello dell'app).
   - Lascia spuntato "Include Live Activity".
   - Lascia DEselezionato "Include Configuration App Intent" (non ci serve per ora).
   - Conferma.
3. **Sostituisci i file generati**:
   - Xcode crea un file con il bundle (`BrindooLiveActivityBundle.swift` o nome simile) e un file widget di esempio. Cancellali tutti.
   - Trascina i 2 file di questa cartella (`BrindooLiveActivityBundle.swift`, `BrindooNegotiationLiveActivity.swift`) nel nuovo target. Quando Xcode chiede "Add to targets", spunta SOLO `BrindooLiveActivity`.
4. **Condividi `NegotiationActivityAttributes.swift`**:
   - Selezionalo in Xcode (`Brindoo/LiveActivities/NegotiationActivityAttributes.swift`).
   - In Inspector → **Target Membership**, spunta ANCHE `BrindooLiveActivity` (oltre a `Brindoo`).
5. **Verifica Info.plist del nuovo target**:
   - Xcode genera l'`Info.plist` del widget con `NSExtensionPointIdentifier = com.apple.widgetkit-extension`. Va bene così.
6. **Deployment target**: imposta il widget extension a iOS 16.2+ (Build Settings → iOS Deployment Target).
7. **Esegui**: il main app si avvia normale. Quando crei/aggiorni/chiudi una trattativa, `LiveActivityManager` chiama l'API ActivityKit e la Live Activity appare in Lock Screen + Dynamic Island.

## Note tecniche

- **No push remoto per ora**: `LiveActivityManager.startOrUpdateNegotiation` viene chiamato in-process dall'app (es. dentro `OfferProposalService`). Per aggiornare la Live Activity da push remoto (anche quando l'app è chiusa) serve un'Edge Function Supabase che invia ad APNs un payload con `aps.event = "update"` + push token dell'Activity. Lo aggiungiamo quando avremo Pro a regime.
- **Permessi**: l'utente può disabilitare le Live Activity da Impostazioni → Live Activity. `LiveActivityManager` controlla `ActivityAuthorizationInfo().areActivitiesEnabled` e diventa no-op silenziosamente.
- **Dismissal**: quando una trattativa viene accettata/rifiutata, l'Activity rimane visibile ~5 minuti dopo l'evento, poi sparisce.
