// Edge Function: delete-account
//
// Elimina l'account di chi chiama. Prima la parte dati (funzione SQL
// `brindoo_delete_account`, che avvisa le controparti e cancella a cascata
// da auth.users), poi i file: se la parte dati fallisce, foto e vocali
// restano al loro posto. Prima l'app cancellava i file per primi e, con
// la funzione SQL rotta, si restava con l'account vivo e le foto sparite.
//
//   POST /functions/v1/delete-account
//   Headers: Authorization: Bearer <JWT utente>

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

// deno-lint-ignore no-explicit-any
async function removeFolder(sb: any, bucket: string, folder: string): Promise<number> {
  let removed = 0;
  for (;;) {
    const { data, error } = await sb.storage.from(bucket).list(folder, { limit: 100 });
    if (error || !data || data.length === 0) return removed;
    const paths = data.map((f: { name: string }) => `${folder}/${f.name}`);
    const { error: rmError } = await sb.storage.from(bucket).remove(paths);
    if (rmError) {
      console.warn(`storage ${bucket}/${folder}:`, rmError.message);
      return removed;
    }
    removed += paths.length;
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data, error } = jwt ? await sb.auth.getUser(jwt) : { data: { user: null }, error: null };
  const userId: string | undefined = data?.user?.id;
  if (error || !userId) return json({ error: "unauthorized" }, 401);

  const { error: rpcError } = await sb.rpc("brindoo_delete_account", { target: userId });
  if (rpcError) {
    console.error("delete-account:", rpcError.message);
    return json({ error: "delete_failed" }, 500);
  }

  // L'app scrive le cartelle sia in maiuscolo (avatar, portfolio) sia in
  // minuscolo (chat): si provano entrambe.
  let files = 0;
  for (const folder of new Set([userId.toUpperCase(), userId.toLowerCase()])) {
    for (const bucket of ["avatars", "portfolio", "chat-images"]) {
      files += await removeFolder(sb, bucket, folder);
    }
  }
  console.log(`🗑️ account eliminato, ${files} file rimossi`);
  return json({ ok: true });
});
