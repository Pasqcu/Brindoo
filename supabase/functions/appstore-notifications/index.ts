// Edge Function: appstore-notifications
//
// Riceve le App Store Server Notifications v2: rinnovi, scadenze,
// rimborsi, revoche arrivano qui anche quando l'utente non apre l'app.
// Prima lo stato Pro sul server si aggiornava solo con l'app aperta: chi
// pagava ma non la apriva risultava scaduto (niente priorita' in vetrina,
// limiti del piano gratuito).
//
// Da configurare in App Store Connect → App → Informazioni app →
// App Store Server Notifications (Produzione e Sandbox, versione 2):
//   https://<progetto>.supabase.co/functions/v1/appstore-notifications
//
// Apple chiama senza JWT (verify_jwt = false in config.toml): l'autenticita'
// la garantisce la firma del payload, verificata sulla catena Apple.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifyAppleJWS } from "../_shared/apple_jws.ts";
import { type AppleTransaction, applyTransaction } from "../_shared/entitlements.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APP_BUNDLE_ID = Deno.env.get("APP_BUNDLE_ID") ?? "com.pasqcu.Brindoo";

interface NotificationPayload {
  notificationType: string;
  subtype?: string;
  notificationUUID: string;
  data?: { bundleId?: string; signedTransactionInfo?: string };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  let signedPayload: string | undefined;
  try {
    signedPayload = (await req.json())?.signedPayload;
  } catch {
    // gestito sotto
  }
  if (!signedPayload) return new Response("signedPayload mancante", { status: 400 });

  let note: NotificationPayload;
  let tx: AppleTransaction | null = null;
  try {
    note = await verifyAppleJWS<NotificationPayload>(signedPayload);
    if (note.data?.bundleId && note.data.bundleId !== APP_BUNDLE_ID) {
      return new Response("bundle inatteso", { status: 400 });
    }
    if (note.data?.signedTransactionInfo) {
      tx = await verifyAppleJWS<AppleTransaction>(note.data.signedTransactionInfo);
    }
  } catch (err) {
    console.error("appstore-notifications: firma rifiutata:", (err as Error).message);
    return new Response("firma non valida", { status: 400 });
  }

  console.log(`📬 ${note.notificationType}${note.subtype ? "/" + note.subtype : ""} ${note.notificationUUID}`);
  if (!tx) return new Response("ok"); // es. TEST: nessuna transazione da applicare

  try {
    const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const result = await applyTransaction(sb, tx, null, APP_BUNDLE_ID);
    if (!result) console.warn("Transazione di un acquisto mai registrato: ignorata");
    return new Response("ok");
  } catch (err) {
    // 500: Apple ritenta piu' tardi.
    console.error("appstore-notifications:", (err as Error).message);
    return new Response("errore", { status: 500 });
  }
});
