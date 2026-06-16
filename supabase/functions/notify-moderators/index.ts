// Edge Function: notify-moderators
//
// Riceve una nuova segnalazione (tabella `reports`) e invia un'email
// al team di moderazione. La invocazione avviene da un trigger AFTER INSERT
// definito nella migration `20260515_reports_and_compliance_notifications.sql`.
//
// Provider email: Resend (https://resend.com), free tier 100 email/giorno.
// Per altri provider basta sostituire la chiamata a sendEmail().
//
// Env vars richieste (da impostare nella dashboard Supabase → Edge Functions):
//   - RESEND_API_KEY       (es. re_abc123...)
//   - REPORT_NOTIFY_EMAIL  (es. pasqcu.app.support@gmail.com)
//   - REPORT_FROM_EMAIL    (es. moderation@brindoo.example o un dominio verificato Resend)
//
// Se RESEND_API_KEY o REPORT_NOTIFY_EMAIL non sono configurate, la function
// risponde 200 OK ma non invia nulla (utile in fase di setup).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const REPORT_NOTIFY_EMAIL = Deno.env.get("REPORT_NOTIFY_EMAIL");
const REPORT_FROM_EMAIL =
  Deno.env.get("REPORT_FROM_EMAIL") ?? "moderation@brindoo.app";

// Payload inviato dal trigger Postgres
interface ReportPayload {
  id: string;
  reporter_id: string;
  target_type: string;
  target_id: string;
  reason: string;
  description: string | null;
  created_at: string;
}

interface ProfileMin {
  id: string;
  full_name: string | null;
  city: string | null;
}

// MARK: - Helpers

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

const REASON_LABELS: Record<string, string> = {
  spam: "Spam o pubblicità",
  inappropriate: "Contenuto inappropriato",
  harassment: "Molestie",
  fake: "Informazioni false",
  impersonation: "Impersonificazione",
  illegal: "Attività illegale",
  other: "Altro",
};

const TARGET_LABELS: Record<string, string> = {
  user: "Utente",
  review: "Recensione",
  message: "Messaggio in chat",
  portfolio_item: "Foto portfolio",
  offer: "Offerta servizio",
};

async function fetchProfile(
  supabase: ReturnType<typeof createClient>,
  userId: string
): Promise<ProfileMin | null> {
  const { data } = await supabase
    .from("profiles")
    .select("id, full_name, city")
    .eq("id", userId)
    .maybeSingle();
  return data as ProfileMin | null;
}

async function sendEmail(
  to: string,
  subject: string,
  html: string
): Promise<void> {
  if (!RESEND_API_KEY) {
    console.warn("⚠️ RESEND_API_KEY non configurata — skip invio email");
    return;
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: REPORT_FROM_EMAIL,
      to: [to],
      subject,
      html,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Resend ${res.status}: ${body}`);
  }
}

function renderEmail(
  report: ReportPayload,
  reporter: ProfileMin | null,
  target: ProfileMin | null
): { subject: string; html: string } {
  const reasonLabel = REASON_LABELS[report.reason] ?? report.reason;
  const targetTypeLabel = TARGET_LABELS[report.target_type] ?? report.target_type;
  const targetName = target?.full_name ?? "(profilo eliminato o non-utente)";
  const reporterName = reporter?.full_name ?? "(profilo eliminato)";
  const description = report.description
    ? escapeHtml(report.description).replace(/\n/g, "<br>")
    : "(nessun dettaglio)";

  const subject = `[Brindoo · Moderazione] Nuova segnalazione — ${reasonLabel}`;

  const html = `<!doctype html>
<html lang="it"><body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#fafafa;padding:24px;color:#1a1a1a;">
  <div style="max-width:560px;margin:0 auto;background:white;border-radius:12px;padding:24px;box-shadow:0 1px 4px rgba(0,0,0,0.05);">
    <h2 style="margin:0 0 16px;color:#FF5A5F;">⚠️ Nuova segnalazione su Brindoo</h2>

    <table style="width:100%;border-collapse:collapse;font-size:14px;">
      <tr><td style="padding:8px 0;color:#666;width:160px;">Tipo</td><td><strong>${escapeHtml(targetTypeLabel)}</strong></td></tr>
      <tr><td style="padding:8px 0;color:#666;">Motivo</td><td><strong>${escapeHtml(reasonLabel)}</strong></td></tr>
      <tr><td style="padding:8px 0;color:#666;">Segnalato</td><td>${escapeHtml(targetName)}<br><code style="font-size:11px;color:#999;">${escapeHtml(report.target_id)}</code></td></tr>
      <tr><td style="padding:8px 0;color:#666;">Segnalatore</td><td>${escapeHtml(reporterName)}<br><code style="font-size:11px;color:#999;">${escapeHtml(report.reporter_id)}</code></td></tr>
      <tr><td style="padding:8px 0;color:#666;">Quando</td><td>${escapeHtml(report.created_at)}</td></tr>
    </table>

    <h3 style="margin:24px 0 8px;font-size:14px;color:#666;">Dettagli forniti</h3>
    <div style="background:#fafafa;padding:12px;border-radius:8px;font-size:14px;line-height:1.5;">${description}</div>

    <p style="margin-top:24px;font-size:13px;color:#888;">
      ID segnalazione: <code>${escapeHtml(report.id)}</code><br>
      Apri la dashboard Supabase → Tabella <code>reports</code> per agire entro 24 ore.
    </p>
  </div>
</body></html>`;

  return { subject, html };
}

// MARK: - HTTP handler

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  if (!REPORT_NOTIFY_EMAIL) {
    console.warn("⚠️ REPORT_NOTIFY_EMAIL non configurata — skip notifica");
    return new Response(JSON.stringify({ ok: true, skipped: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json();
    const report: ReportPayload = body.record ?? body;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const [reporter, target] = await Promise.all([
      fetchProfile(supabase, report.reporter_id),
      report.target_type === "user"
        ? fetchProfile(supabase, report.target_id)
        : Promise.resolve(null),
    ]);

    const { subject, html } = renderEmail(report, reporter, target);
    await sendEmail(REPORT_NOTIFY_EMAIL, subject, html);

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("❌ notify-moderators:", message);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
