// Applica una transazione Apple (gia' verificata) ai diritti di un account.
// Usata da `validate-iap-receipt` (l'app manda la transazione) e da
// `appstore-notifications` (Apple avvisa rinnovi, scadenze, rimborsi).
//
// Regole:
//   * un acquisto appartiene a un solo account Brindoo: quello indicato da
//     `appAccountToken` (lo mette l'app al momento dell'acquisto) oppure,
//     per gli acquisti vecchi senza token, il primo account che l'ha
//     registrato. Un secondo account sullo stesso ID Apple non diventa Pro;
//   * ogni transazione conta una volta sola (`purchases.transaction_id`
//     unico): un Boost ripresentato non si allunga di nuovo;
//   * una transazione revocata (rimborso) toglie quello che aveva dato;
//   * ogni errore del database si propaga: rispondere "ok" senza aver
//     scritto faceva chiudere all'app una transazione mai registrata.

// deno-lint-ignore no-explicit-any
type Client = any;

export interface AppleTransaction {
  transactionId: string | number;
  originalTransactionId: string | number;
  bundleId: string;
  productId: string;
  purchaseDate: number;
  expiresDate?: number;
  revocationDate?: number;
  appAccountToken?: string;
}

export interface ApplyResult {
  ownerId: string;
  productId: string;
  expiresDate: string | null;
}

export const PRODUCTS: Record<string, { type: "subscription" } | { type: "boost"; days: number }> = {
  "com.pasqcu.Brindoo.pro.monthly": { type: "subscription" },
  "com.pasqcu.Brindoo.boost.1day": { type: "boost", days: 1 },
  "com.pasqcu.Brindoo.boost.1week": { type: "boost", days: 7 },
};

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DAY_MS = 24 * 60 * 60 * 1000;

function iso(ms: number | undefined): string | null {
  return ms ? new Date(ms).toISOString() : null;
}

function check<T>(res: { data: T; error: { message: string } | null }, what: string): T {
  if (res.error) throw new Error(`${what}: ${res.error.message}`);
  return res.data;
}

async function resolveOwner(sb: Client, tx: AppleTransaction, callerId: string | null): Promise<string | null> {
  const token = tx.appAccountToken?.toLowerCase();
  if (token && UUID_RE.test(token)) return token;

  const rows = check(
    await sb.from("purchases")
      .select("user_id")
      .eq("original_transaction_id", String(tx.originalTransactionId))
      .order("created_at", { ascending: true })
      .limit(1),
    "lettura proprietario",
  ) as { user_id: string }[];
  return rows[0]?.user_id ?? callerId;
}

export async function applyTransaction(
  sb: Client,
  tx: AppleTransaction,
  callerId: string | null,
  bundleId: string,
): Promise<ApplyResult | null> {
  if (tx.bundleId !== bundleId) {
    throw new Error(`bundleId inatteso: ${tx.bundleId}`);
  }
  const product = PRODUCTS[tx.productId];
  if (!product) throw new Error(`Prodotto sconosciuto: ${tx.productId}`);

  const ownerId = await resolveOwner(sb, tx, callerId);
  if (!ownerId) return null; // notifica per un acquisto mai visto: nessuno da aggiornare

  const revoked = !!tx.revocationDate;
  const transactionId = String(tx.transactionId);

  // Registra la transazione una volta sola. `inserted` vuoto = gia' vista.
  const inserted = check(
    await sb.from("purchases")
      .upsert({
        user_id: ownerId,
        product_id: tx.productId,
        transaction_id: transactionId,
        original_transaction_id: String(tx.originalTransactionId),
        purchase_date: iso(tx.purchaseDate),
        expires_date: iso(tx.expiresDate),
        is_subscription: product.type === "subscription",
        revoked_at: revoked ? iso(tx.revocationDate) : null,
      }, { onConflict: "transaction_id", ignoreDuplicates: true })
      .select("id"),
    "registrazione acquisto",
  ) as { id: string }[];
  const isNew = inserted.length > 0;

  // Revoca arrivata dopo la registrazione: va segnata, una volta sola.
  let newlyRevoked = false;
  if (revoked && !isNew) {
    const marked = check(
      await sb.from("purchases")
        .update({ revoked_at: iso(tx.revocationDate) })
        .eq("transaction_id", transactionId)
        .is("revoked_at", null)
        .select("id"),
      "revoca acquisto",
    ) as { id: string }[];
    newlyRevoked = marked.length > 0;
  }

  if (product.type === "subscription") {
    // La scadenza Apple e' la piu' lontana fra le transazioni non revocate:
    // l'ordine d'arrivo non conta e un rimborso toglie solo quel periodo.
    const subs = check(
      await sb.from("purchases")
        .select("expires_date")
        .eq("user_id", ownerId)
        .eq("is_subscription", true)
        .is("revoked_at", null)
        .order("expires_date", { ascending: false, nullsFirst: false })
        .limit(1),
      "lettura abbonamento",
    ) as { expires_date: string | null }[];
    check(
      await sb.from("profiles")
        .update({ iap_pro_expires_at: subs[0]?.expires_date ?? null })
        .eq("id", ownerId),
      "aggiornamento Pro",
    );
  } else if ((isNew && !revoked) || newlyRevoked) {
    const prof = check(
      await sb.from("profiles").select("boost_expires_at").eq("id", ownerId).maybeSingle(),
      "lettura Boost",
    ) as { boost_expires_at: string | null } | null;
    const now = Date.now();
    const current = prof?.boost_expires_at ? Date.parse(prof.boost_expires_at) : now;
    let next: number;
    if (newlyRevoked) {
      next = Math.max(now, current - product.days * DAY_MS);
    } else {
      next = Math.max(current, now) + product.days * DAY_MS;
    }
    check(
      await sb.from("profiles")
        .update({ boost_expires_at: new Date(next).toISOString() })
        .eq("id", ownerId),
      "aggiornamento Boost",
    );
  }

  return { ownerId, productId: tx.productId, expiresDate: iso(tx.expiresDate) };
}
