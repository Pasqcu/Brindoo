// Edge Function: validate-iap-receipt
//
// Verifica lato server una transazione StoreKit 2 (JWS firmato da Apple) e
// aggiorna gli entitlement dell'utente sul DB con service_role.
//
// Il client iOS (PurchaseService.swift) invia il `signedTransaction` JWS
// che ha già passato `VerificationResult.verified` lato app.  Verifichiamo
// di nuovo lato server perché il client può essere compromesso.
//
// Flow:
//   1. Decodifica l'header JWS, estrae la catena di certificati x5c
//   2. Verifica la firma del JWS usando il leaf certificate
//   3. Verifica che la catena risalga ad Apple Root CA - G3 (fingerprint hardcoded)
//   4. Verifica bundleId, productId, e che la transazione non sia revocata/scaduta
//   5. Aggiorna profiles.pro_expires_at oppure profiles.boost_expires_at
//   6. Registra l'acquisto in `purchases` (idempotente via transaction_id)
//
// Endpoints richiesti dal client:
//   POST /functions/v1/validate-iap-receipt
//   Body: { "signed_transaction": "<JWS string>" }
//   Headers: Authorization: Bearer <user JWT>
//
// Env vars:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (provided by Supabase)
//   APP_BUNDLE_ID                            (es. "com.pasqcu.Brindoo")

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { decodeProtectedHeader, jwtVerify, importX509 } from "jose";

// MARK: - Costanti

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APP_BUNDLE_ID = Deno.env.get("APP_BUNDLE_ID") ?? "com.pasqcu.Brindoo";

// SHA-256 fingerprint dell'Apple Root CA - G3 (root della catena con cui
// Apple firma le transazioni StoreKit 2). Hex uppercase, separato da `:`.
// Riferimento: https://www.apple.com/certificateauthority/
const APPLE_ROOT_G3_FINGERPRINT_SHA256 =
  "63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79";

// Mapping product → tipo e durata
const PRODUCTS = {
  "com.pasqcu.Brindoo.pro.monthly": { type: "subscription" as const },
  "com.pasqcu.Brindoo.boost.1day":  { type: "boost" as const, days: 1 },
  "com.pasqcu.Brindoo.boost.1week": { type: "boost" as const, days: 7 },
};

// MARK: - Tipi payload Apple

interface AppleTransactionPayload {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  purchaseDate: number;            // millis since epoch
  originalPurchaseDate: number;
  expiresDate?: number;            // solo per subscription
  type: string;                    // "Auto-Renewable Subscription" | "Consumable" | ...
  revocationDate?: number;
  revocationReason?: number;
  inAppOwnershipType?: string;
  signedDate: number;
}

// MARK: - Helpers PKI

function pemFromDer(der: Uint8Array): string {
  let b64 = "";
  for (let i = 0; i < der.length; i++) b64 += String.fromCharCode(der[i]);
  const wrapped = btoa(b64).replace(/(.{64})/g, "$1\n");
  return `-----BEGIN CERTIFICATE-----\n${wrapped}\n-----END CERTIFICATE-----\n`;
}

async function sha256Hex(data: Uint8Array): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0").toUpperCase())
    .join(":");
}

// MARK: - Verifica JWS Apple

async function verifyAppleJWS(jws: string): Promise<AppleTransactionPayload> {
  // 1. Estrai x5c dall'header
  const header = decodeProtectedHeader(jws);
  if (!header.x5c || header.x5c.length === 0) {
    throw new Error("JWS header missing x5c certificate chain");
  }

  const chainDer = header.x5c.map((b64: string) =>
    Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
  );

  // 2. Verifica che l'ultimo cert della catena sia Apple Root CA - G3
  const rootCert = chainDer[chainDer.length - 1];
  const rootFingerprint = await sha256Hex(rootCert);
  if (rootFingerprint !== APPLE_ROOT_G3_FINGERPRINT_SHA256) {
    throw new Error(
      `Root certificate fingerprint mismatch. Expected Apple Root CA - G3, got ${rootFingerprint}`
    );
  }

  // 3. Importa il leaf cert e verifica la firma del JWS
  const leafPem = pemFromDer(chainDer[0]);
  const publicKey = await importX509(leafPem, "ES256");

  const { payload } = await jwtVerify(jws, publicKey, {
    algorithms: ["ES256"],
  });

  return payload as unknown as AppleTransactionPayload;
}

// MARK: - Aggiornamento entitlement

function isoDateOrNull(millis: number | undefined): string | null {
  if (!millis) return null;
  return new Date(millis).toISOString();
}

async function applyEntitlement(
  userId: string,
  payload: AppleTransactionPayload
): Promise<void> {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Verifica bundleId
  if (payload.bundleId !== APP_BUNDLE_ID) {
    throw new Error(
      `bundleId mismatch: expected ${APP_BUNDLE_ID}, got ${payload.bundleId}`
    );
  }

  // Transazione revocata → niente entitlement
  if (payload.revocationDate) {
    console.log(`⚠️ Transaction ${payload.transactionId} revoked, skipping`);
  }

  const productMeta = PRODUCTS[payload.productId as keyof typeof PRODUCTS];
  if (!productMeta) {
    throw new Error(`Unknown productId: ${payload.productId}`);
  }

  // 1. Registra l'acquisto (idempotente via transaction_id)
  await supabase
    .from("purchases")
    .upsert(
      {
        user_id: userId,
        product_id: payload.productId,
        transaction_id: String(payload.transactionId),
        original_transaction_id: String(payload.originalTransactionId),
        purchase_date: isoDateOrNull(payload.purchaseDate),
        expires_date: isoDateOrNull(payload.expiresDate),
        is_subscription: productMeta.type === "subscription",
      },
      { onConflict: "transaction_id" }
    );

  // 2. Aggiorna l'entitlement
  if (productMeta.type === "subscription") {
    // Per Pro: l'expires_date arriva direttamente da Apple
    const proExpires =
      !payload.revocationDate && payload.expiresDate
        ? isoDateOrNull(payload.expiresDate)
        : null;

    await supabase
      .from("profiles")
      .update({ pro_expires_at: proExpires })
      .eq("id", userId);
  } else if (productMeta.type === "boost") {
    // Per Boost: estendi di N giorni dalla scadenza attuale (se ancora valida)
    // o da adesso (se scaduto/mai avuto).
    const { data: profile } = await supabase
      .from("profiles")
      .select("boost_expires_at")
      .eq("id", userId)
      .single();

    const now = new Date();
    const currentExpiry = profile?.boost_expires_at
      ? new Date(profile.boost_expires_at)
      : now;
    const base = currentExpiry > now ? currentExpiry : now;
    const newExpiry = new Date(
      base.getTime() + productMeta.days * 24 * 60 * 60 * 1000
    );

    await supabase
      .from("profiles")
      .update({ boost_expires_at: newExpiry.toISOString() })
      .eq("id", userId);
  }
}

// MARK: - Risoluzione user dal JWT

async function getUserIdFromAuthHeader(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  if (!jwt) return null;

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data, error } = await supabase.auth.getUser(jwt);
  if (error || !data.user) return null;
  return data.user.id;
}

// MARK: - HTTP handler

Deno.serve(async (req) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers":
          "Authorization, Content-Type, x-client-info, apikey",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const corsHeaders = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
  };

  try {
    const userId = await getUserIdFromAuthHeader(req);
    if (!userId) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: corsHeaders,
      });
    }

    const body = await req.json();
    const signedTransaction: string | undefined = body?.signed_transaction;
    if (!signedTransaction) {
      return new Response(
        JSON.stringify({ error: "signed_transaction is required" }),
        { status: 400, headers: corsHeaders }
      );
    }

    const payload = await verifyAppleJWS(signedTransaction);
    await applyEntitlement(userId, payload);

    return new Response(
      JSON.stringify({
        ok: true,
        product_id: payload.productId,
        expires_date: isoDateOrNull(payload.expiresDate),
      }),
      { status: 200, headers: corsHeaders }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("❌ validate-iap-receipt:", message);
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: corsHeaders,
    });
  }
});
