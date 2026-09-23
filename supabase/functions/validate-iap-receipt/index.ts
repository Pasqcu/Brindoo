// Edge Function: validate-iap-receipt
//
// L'app manda il JWS di una transazione StoreKit 2; qui lo si verifica
// (catena di certificati Apple completa, vedi _shared/apple_jws.ts) e si
// aggiornano i diritti dell'account proprietario con service_role
// (vedi _shared/entitlements.ts).
//
//   POST /functions/v1/validate-iap-receipt
//   Body: { "signed_transaction": "<JWS>" }
//   Headers: Authorization: Bearer <JWT utente>
//
// Risposta 200: { ok, product_id, expires_date, owner_matches }
//   owner_matches = false quando l'acquisto appartiene a un altro account
//   Brindoo (stesso ID Apple): il diritto resta a quello, non passa a chi
//   ha fatto la richiesta. La transazione e' comunque registrata, quindi
//   l'app puo' chiuderla.
//
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, APP_BUNDLE_ID

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifyAppleJWS } from "../_shared/apple_jws.ts";
import { type AppleTransaction, applyTransaction } from "../_shared/entitlements.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APP_BUNDLE_ID = Deno.env.get("APP_BUNDLE_ID") ?? "com.pasqcu.Brindoo";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Authorization, Content-Type, x-client-info, apikey",
      },
    });
  }
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: userData, error: userError } = jwt
    ? await sb.auth.getUser(jwt)
    : { data: { user: null }, error: null };
  const userId = userData?.user?.id ?? null;
  if (userError || !userId) return json({ error: "unauthorized" }, 401);

  let signed: string | undefined;
  try {
    signed = (await req.json())?.signed_transaction;
  } catch {
    // corpo non JSON: gestito sotto
  }
  if (!signed) return json({ error: "signed_transaction is required" }, 400);

  let tx: AppleTransaction;
  try {
    tx = await verifyAppleJWS<AppleTransaction>(signed);
  } catch (err) {
    // Firma o catena non valide: rifiuto definitivo, l'app non deve riprovare.
    console.error("validate-iap-receipt: JWS rifiutato:", (err as Error).message);
    return json({ error: "invalid_transaction" }, 400);
  }

  try {
    const result = await applyTransaction(sb, tx, userId, APP_BUNDLE_ID);
    return json({
      ok: true,
      product_id: tx.productId,
      expires_date: result?.expiresDate ?? null,
      owner_matches: result?.ownerId === userId,
    });
  } catch (err) {
    // Errore del database: 500, cosi' l'app lascia aperta la transazione e riprova.
    console.error("validate-iap-receipt:", (err as Error).message);
    return json({ error: "server_error" }, 500);
  }
});
