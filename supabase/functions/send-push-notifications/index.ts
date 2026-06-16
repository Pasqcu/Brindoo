// Edge Function: send-push-notifications
// Legge la outbox e invia notifiche push via APNs HTTP/2.
// Schedulata via pg_cron ogni minuto.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

// MARK: - Tipi

interface NotificationRow {
  id: string;
  recipient_id: string;
  title: string;
  body: string;
  payload: Record<string, unknown> | null;
}

interface DeviceTokenRow {
  id: string;
  user_id: string;
  token: string;
  platform: string;
}

// MARK: - Setup

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID")!;
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;
const APNS_USE_SANDBOX = Deno.env.get("APNS_USE_SANDBOX") === "true";

const APNS_HOST = APNS_USE_SANDBOX
  ? "api.sandbox.push.apple.com"
  : "api.push.apple.com";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// MARK: - JWT signing per APNs

let cachedJwt: { token: string; expiresAt: number } | null = null;
let cachedKey: CryptoKey | null = null;

async function importPrivateKey(): Promise<CryptoKey> {
  if (cachedKey) return cachedKey;

  // La chiave .p8 è in formato PEM, va decodificata in PKCS8 binario
  const pemContents = APNS_PRIVATE_KEY
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  cachedKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  return cachedKey;
}

async function getApnsJwt(): Promise<string> {
  // Apple richiede un nuovo JWT ogni 20-60 minuti
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && cachedJwt.expiresAt > now + 300) {
    return cachedJwt.token;
  }

  const key = await importPrivateKey();

  const token = await create(
    { alg: "ES256", kid: APNS_KEY_ID, typ: "JWT" },
    { iss: APNS_TEAM_ID, iat: getNumericDate(0) },
    key,
  );

  cachedJwt = {
    token,
    expiresAt: now + 50 * 60, // 50 minuti
  };

  return token;
}

// MARK: - Invio notifica APNs

interface ApnsResult {
  success: boolean;
  status: number;
  shouldRemoveToken: boolean;
  reason?: string;
}

async function sendToApns(
  deviceToken: string,
  notification: NotificationRow,
): Promise<ApnsResult> {
  const jwt = await getApnsJwt();

  const url = `https://${APNS_HOST}/3/device/${deviceToken}`;

  const aps = {
    alert: {
      title: notification.title,
      body: notification.body,
    },
    sound: "default",
    badge: 1,
    "mutable-content": 1,
  };

  // Combina aps + payload custom (type, conversation_id, ecc.)
  const body = {
    aps,
    ...(notification.payload ?? {}),
  };

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "authorization": `bearer ${jwt}`,
        "apns-topic": APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (response.status === 200) {
      return { success: true, status: 200, shouldRemoveToken: false };
    }

    let reason = "";
    try {
      const json = await response.json();
      reason = json.reason ?? "";
    } catch {
      // ignore
    }

    // 410 Gone = token non più valido (app disinstallata)
    // BadDeviceToken = token mai stato valido
    const shouldRemove = response.status === 410 ||
      reason === "BadDeviceToken" ||
      reason === "Unregistered";

    return {
      success: false,
      status: response.status,
      shouldRemoveToken: shouldRemove,
      reason,
    };
  } catch (error) {
    console.error("Errore network APNs:", error);
    return {
      success: false,
      status: 0,
      shouldRemoveToken: false,
      reason: String(error),
    };
  }
}

// MARK: - Main handler

Deno.serve(async (_req) => {
  const startedAt = Date.now();

  try {
    // 1. Recupera notifiche non ancora inviate (max 100 per esecuzione)
    const { data: notifications, error: fetchError } = await supabase
      .from("notifications_outbox")
      .select("*")
      .eq("sent", false)
      .order("created_at", { ascending: true })
      .limit(100);

    if (fetchError) {
      console.error("Errore fetch outbox:", fetchError);
      return new Response(
        JSON.stringify({ error: fetchError.message }),
        { status: 500, headers: { "content-type": "application/json" } },
      );
    }

    if (!notifications || notifications.length === 0) {
      return new Response(
        JSON.stringify({ processed: 0, message: "Nessuna notifica" }),
        { headers: { "content-type": "application/json" } },
      );
    }

    console.log(`📨 Processo ${notifications.length} notifiche`);

    let totalSent = 0;
    let totalFailed = 0;
    const tokensToRemove: string[] = [];

    // 2. Per ogni notifica, recupera i token e invia
    for (const notification of notifications as NotificationRow[]) {
      const { data: tokens, error: tokensError } = await supabase
        .from("device_tokens")
        .select("*")
        .eq("user_id", notification.recipient_id);

      if (tokensError) {
        console.error("Errore fetch tokens:", tokensError);
        continue;
      }

      if (!tokens || tokens.length === 0) {
        // Nessun device registrato → marca come sent comunque (no destinatario)
        await supabase
          .from("notifications_outbox")
          .update({ sent: true, sent_at: new Date().toISOString() })
          .eq("id", notification.id);
        continue;
      }

      // Invia a tutti i device dell'utente
      let anySuccess = false;
      for (const token of tokens as DeviceTokenRow[]) {
        const result = await sendToApns(token.token, notification);

        if (result.success) {
          anySuccess = true;
          totalSent++;
        } else {
          totalFailed++;
          console.warn(
            `⚠️ Send failed: status=${result.status} reason=${result.reason}`,
          );
          if (result.shouldRemoveToken) {
            tokensToRemove.push(token.id);
          }
        }
      }

      // 3. Marca la notifica come sent (almeno uno dei device l'ha ricevuta)
      if (anySuccess || tokens.length > 0) {
        await supabase
          .from("notifications_outbox")
          .update({ sent: true, sent_at: new Date().toISOString() })
          .eq("id", notification.id);
      }
    }

    // 4. Rimuovi i token invalidi
    if (tokensToRemove.length > 0) {
      await supabase
        .from("device_tokens")
        .delete()
        .in("id", tokensToRemove);
      console.log(`🗑️ Rimossi ${tokensToRemove.length} token invalidi`);
    }

    const elapsed = Date.now() - startedAt;
    console.log(
      `✅ Completato in ${elapsed}ms — sent: ${totalSent}, failed: ${totalFailed}`,
    );

    return new Response(
      JSON.stringify({
        processed: notifications.length,
        sent: totalSent,
        failed: totalFailed,
        removedTokens: tokensToRemove.length,
        elapsedMs: elapsed,
      }),
      { headers: { "content-type": "application/json" } },
    );
  } catch (error) {
    console.error("❌ Errore generale:", error);
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: { "content-type": "application/json" } },
    );
  }
});
