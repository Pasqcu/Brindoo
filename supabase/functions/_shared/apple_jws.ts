// Verifica dei JWS firmati da Apple (transazioni StoreKit 2 e notifiche
// App Store Server v2), solo con WebCrypto: gira identico su Deno (edge
// function) e su Node (test locali), senza dipendenze.
//
// Cosa si controlla, e perche':
//   1. la catena x5c ha tre certificati: foglia, intermedio, radice;
//   2. la radice e' Apple Root CA - G3 (impronta SHA-256 fissata);
//   3. l'intermedio e' firmato dalla radice, la foglia dall'intermedio.
//      Senza questo passo bastava accodare la radice vera (pubblica) a una
//      foglia inventata per far passare una transazione falsa;
//   4. intermedio e foglia portano i contrassegni (OID) che Apple mette sui
//      certificati di firma delle transazioni;
//   5. ogni certificato era valido alla data in cui Apple ha firmato;
//   6. la firma ES256 del JWS e' della foglia.

export const APPLE_ROOT_G3_SHA256 =
  "63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79";

// 1.2.840.113635.100.6.11.1 (foglia) e 1.2.840.113635.100.6.2.1 (intermedio), gia' codificati DER.
const OID_APPLE_LEAF = [0x06, 0x0a, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06, 0x0b, 0x01];
const OID_APPLE_INTERMEDIATE = [0x06, 0x0a, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06, 0x02, 0x01];

export interface VerifyOptions {
  /** Impronta attesa della radice (per i test si usa una radice locale). */
  rootFingerprint?: string;
  /** Richiede gli OID Apple su foglia e intermedio (default: si'). */
  requireAppleOids?: boolean;
  /** Istante (ms) in cui i certificati devono essere validi; default: signedDate del payload o adesso. */
  at?: number;
}

// MARK: - DER minimo

interface Tlv { tag: number; start: number; headerLen: number; end: number }

function readTlv(buf: Uint8Array, pos: number): Tlv {
  if (pos + 2 > buf.length) throw new Error("DER troncato");
  const tag = buf[pos];
  let len = buf[pos + 1];
  let headerLen = 2;
  if (len & 0x80) {
    const n = len & 0x7f;
    if (n === 0 || n > 4) throw new Error("DER: lunghezza non supportata");
    len = 0;
    for (let i = 0; i < n; i++) len = len * 256 + buf[pos + 2 + i];
    headerLen = 2 + n;
  }
  const end = pos + headerLen + len;
  if (end > buf.length) throw new Error("DER fuori dai limiti");
  return { tag, start: pos, headerLen, end };
}

function children(buf: Uint8Array, parent: Tlv): Tlv[] {
  const out: Tlv[] = [];
  let p = parent.start + parent.headerLen;
  while (p < parent.end) {
    const c = readTlv(buf, p);
    out.push(c);
    p = c.end;
  }
  return out;
}

function content(buf: Uint8Array, t: Tlv): Uint8Array {
  return buf.subarray(t.start + t.headerLen, t.end);
}

function oid(buf: Uint8Array, t: Tlv): string {
  const b = content(buf, t);
  const parts = [Math.floor(b[0] / 40), b[0] % 40];
  let v = 0;
  for (let i = 1; i < b.length; i++) {
    v = v * 128 + (b[i] & 0x7f);
    if (!(b[i] & 0x80)) { parts.push(v); v = 0; }
  }
  return parts.join(".");
}

function time(buf: Uint8Array, t: Tlv): number {
  const s = new TextDecoder().decode(content(buf, t));
  const full = t.tag === 0x17 ? (Number(s.slice(0, 2)) >= 50 ? "19" : "20") + s : s;
  const iso = `${full.slice(0, 4)}-${full.slice(4, 6)}-${full.slice(6, 8)}T` +
    `${full.slice(8, 10)}:${full.slice(10, 12)}:${full.slice(12, 14)}Z`;
  const ms = Date.parse(iso);
  if (Number.isNaN(ms)) throw new Error("Data certificato non leggibile");
  return ms;
}

function contains(hay: Uint8Array, needle: number[]): boolean {
  outer: for (let i = 0; i + needle.length <= hay.length; i++) {
    for (let j = 0; j < needle.length; j++) if (hay[i + j] !== needle[j]) continue outer;
    return true;
  }
  return false;
}

// MARK: - Certificati

interface Cert {
  der: Uint8Array;
  tbs: Uint8Array;
  sigHash: "SHA-256" | "SHA-384";
  sigDer: Uint8Array;
  spki: Uint8Array;
  curve: "P-256" | "P-384";
  notBefore: number;
  notAfter: number;
}

const CURVES: Record<string, "P-256" | "P-384"> = {
  "1.2.840.10045.3.1.7": "P-256",
  "1.3.132.0.34": "P-384",
};
const SIG_HASH: Record<string, "SHA-256" | "SHA-384"> = {
  "1.2.840.10045.4.3.2": "SHA-256",
  "1.2.840.10045.4.3.3": "SHA-384",
};

function parseCert(der: Uint8Array): Cert {
  const root = readTlv(der, 0);
  const [tbsT, algT, sigT] = children(der, root);
  const sigHash = SIG_HASH[oid(der, children(der, algT)[0])];
  if (!sigHash) throw new Error("Algoritmo di firma del certificato non supportato");

  const tbsKids = children(der, tbsT);
  const i = tbsKids[0].tag === 0xa0 ? 1 : 0; // version [0] opzionale
  const validity = children(der, tbsKids[i + 3]);
  const spkiT = tbsKids[i + 5];
  const spkiAlg = children(der, children(der, spkiT)[0]);
  const curve = CURVES[oid(der, spkiAlg[1])];
  if (!curve) throw new Error("Curva della chiave non supportata");

  return {
    der,
    tbs: der.subarray(tbsT.start, tbsT.end),
    sigHash,
    sigDer: content(der, sigT).subarray(1), // primo byte: bit inutilizzati
    spki: der.subarray(spkiT.start, spkiT.end),
    curve,
    notBefore: time(der, validity[0]),
    notAfter: time(der, validity[1]),
  };
}

/** Firma ECDSA da DER (SEQUENCE{r,s}) al formato grezzo r||s di WebCrypto. */
function ecdsaDerToRaw(sig: Uint8Array, size: number): Uint8Array {
  const seq = readTlv(sig, 0);
  const [rT, sT] = children(sig, seq);
  const out = new Uint8Array(size * 2);
  [rT, sT].forEach((t, k) => {
    let v = content(sig, t);
    while (v.length > size && v[0] === 0) v = v.subarray(1);
    if (v.length > size) throw new Error("Firma ECDSA non valida");
    out.set(v, k * size + (size - v.length));
  });
  return out;
}

async function importKey(c: Cert): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "spki", c.spki, { name: "ECDSA", namedCurve: c.curve }, false, ["verify"],
  );
}

async function signedBy(child: Cert, issuer: Cert): Promise<boolean> {
  const key = await importKey(issuer);
  const raw = ecdsaDerToRaw(child.sigDer, issuer.curve === "P-256" ? 32 : 48);
  return await crypto.subtle.verify({ name: "ECDSA", hash: child.sigHash }, key, raw, child.tbs);
}

async function fingerprint(der: Uint8Array): Promise<string> {
  const h = new Uint8Array(await crypto.subtle.digest("SHA-256", der));
  return Array.from(h).map((b) => b.toString(16).padStart(2, "0").toUpperCase()).join(":");
}

// MARK: - JWS

function b64urlToBytes(s: string): Uint8Array {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4);
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

function b64ToBytes(s: string): Uint8Array {
  return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
}

/**
 * Verifica un JWS firmato da Apple e ne restituisce il payload.
 * Lancia un errore se qualunque controllo fallisce.
 */
export async function verifyAppleJWS<T = Record<string, unknown>>(
  jws: string,
  options: VerifyOptions = {},
): Promise<T> {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("JWS malformato");
  const [h64, p64, s64] = parts;

  const header = JSON.parse(new TextDecoder().decode(b64urlToBytes(h64)));
  if (header.alg !== "ES256") throw new Error("Algoritmo JWS non atteso");
  const x5c: string[] = header.x5c ?? [];
  if (x5c.length !== 3) throw new Error("Catena di certificati incompleta");

  const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(p64)));
  const [leaf, intermediate, root] = x5c.map((c) => parseCert(b64ToBytes(c)));

  const expected = options.rootFingerprint ?? APPLE_ROOT_G3_SHA256;
  if ((await fingerprint(root.der)) !== expected) {
    throw new Error("La radice della catena non e' Apple Root CA - G3");
  }
  if (!(await signedBy(intermediate, root))) throw new Error("Intermedio non firmato dalla radice");
  if (!(await signedBy(leaf, intermediate))) throw new Error("Foglia non firmata dall'intermedio");

  if (options.requireAppleOids ?? true) {
    if (!contains(leaf.tbs, OID_APPLE_LEAF)) throw new Error("Foglia senza contrassegno Apple");
    if (!contains(intermediate.tbs, OID_APPLE_INTERMEDIATE)) {
      throw new Error("Intermedio senza contrassegno Apple");
    }
  }

  const at = options.at ??
    (typeof payload.signedDate === "number" ? payload.signedDate : Date.now());
  for (const c of [leaf, intermediate, root]) {
    if (at < c.notBefore || at > c.notAfter) throw new Error("Certificato fuori validita'");
  }

  if (leaf.curve !== "P-256") throw new Error("Chiave della foglia non ES256");
  const ok = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    await importKey(leaf),
    b64urlToBytes(s64),
    new TextEncoder().encode(`${h64}.${p64}`),
  );
  if (!ok) throw new Error("Firma del JWS non valida");

  return payload as T;
}
