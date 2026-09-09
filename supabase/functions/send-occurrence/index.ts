import { PDFDocument, rgb, StandardFonts } from "npm:pdf-lib@1.17.1";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
export const base64 = (bytes: Uint8Array) => {
  let s = "";
  for (const byte of bytes) s += String.fromCharCode(byte);
  return btoa(s);
};
type RecordData = {
  id: string;
  version: number;
  status: string;
  students: { nome: string; turma: string; ra?: string };
  professor: string;
  occurrence_date: string;
  motivos: string[];
  relato: string;
  providencias: string[];
  change_reason?: string;
};
export async function canonicalPdf(o: RecordData) {
  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  let page = doc.addPage([595.28, 841.89]), y = 788;
  const line = (text: string, size = 11, strong = false) => {
    if (y < 65) {
      page = doc.addPage([595.28, 841.89]);
      y = 788;
    }
    page.drawText(text, {
      x: 40,
      y,
      size,
      font: strong ? bold : font,
      color: strong ? rgb(.04, .17, .37) : rgb(0, 0, 0),
    });
    y -= size + 6;
  };
  // Quebrar inclusive palavras longas; símbolos não suportados causam erro antes do envio.
  const paragraph = (text: string, strong = false) => {
    let row = "";
    for (const char of text.normalize("NFC")) {
      if (char === "\r") continue;
      if (char === "\n" || font.widthOfTextAtSize(row + char, 11) > 510) {
        line(row, 11, strong);
        row = "";
        if (char === "\n") continue;
      }
      row += char;
    }
    if (row) line(row, 11, strong);
    y -= 5;
  };
  line("E.E. JOÃO PAULO II", 18, true);
  line("Ficha de ocorrência escolar", 13);
  y -= 14;
  if (o.status === "cancelled") {
    line("CANCELADA", 16, true);
    paragraph(o.change_reason ?? "");
  }
  paragraph(`Aluno: ${o.students.nome}`);
  paragraph(`Turma: ${o.students.turma}`);
  if (o.students.ra) paragraph(`RA/matrícula: ${o.students.ra}`);
  paragraph(`Professor: ${o.professor}`);
  paragraph(`Data: ${o.occurrence_date.split("-").reverse().join("/")}`);
  paragraph("Motivos", true);
  for (const reason of o.motivos) paragraph("- " + reason);
  paragraph("Relato", true);
  paragraph(o.relato || "Não informado");
  paragraph("Providências", true);
  for (const action of o.providencias) paragraph("- " + action);
  if (!o.providencias.length) paragraph("Não informadas");
  const pages = doc.getPages();
  pages.forEach((p, i) => {
    p.drawText(`Registro ${o.id} | Versão ${o.version}`, {
      x: 40,
      y: 36,
      size: 8,
      font,
    });
    p.drawText(`Histórico oficial no sistema. | ${i + 1}/${pages.length}`, {
      x: 40,
      y: 24,
      size: 8,
      font,
    });
  });
  return doc.save();
}
export function mimeMessage(
  sender: string,
  recipients: string[],
  id: string,
  pdf: Uint8Array,
) {
  if (
    !/^[^\s@,<>]+@[^\s@,<>]+\.[^\s@,<>]+$/.test(sender) ||
    recipients.some((e) => !/^[^\s@,<>]+@[^\s@,<>]+\.[^\s@,<>]+$/.test(e))
  ) throw Error("Endereço inválido");
  const boundary = "ocorrencias_" + id;
  const encoded = base64(pdf).match(/.{1,76}/g)!.join("\r\n");
  return [
    `From: ${sender}`,
    `To: ${recipients.join(", ")}`,
    "Subject: Ocorrencia escolar - E.E. Joao Paulo II",
    `Message-ID: <${id}@ocorrencias-v2.local>`,
    "MIME-Version: 1.0",
    `Content-Type: multipart/mixed; boundary="${boundary}"`,
    "",
    `--${boundary}`,
    "Content-Type: text/plain; charset=UTF-8",
    "Content-Transfer-Encoding: base64",
    "",
    base64(
      new TextEncoder().encode(
        "Segue a ficha de ocorrência escolar em anexo. O histórico oficial permanece no sistema.",
      ),
    ),
    `--${boundary}`,
    "Content-Type: application/pdf",
    `Content-Disposition: attachment; filename="ocorrencia-${id}.pdf"`,
    "Content-Transfer-Encoding: base64",
    "",
    encoded,
    `--${boundary}--`,
    "",
  ].join("\r\n");
}
export async function handler(req: Request) {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") {
    return reply({ error: "Método não permitido." }, 405);
  }
  const url = Deno.env.get("SUPABASE_URL")!,
    key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const rest = async (path: string, body?: unknown, method?: string) => {
    const r = await fetch(url + "/rest/v1/" + path, {
      method: method ?? (body ? "POST" : "GET"),
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(15000),
    });
    const text = await r.text();
    return { ok: r.ok, data: text ? JSON.parse(text) : null };
  };
  let deliveryId: string | undefined;
  let sending = false;
  const finish = async (status: string, message_id?: string) => {
    const r = await rest(
      `email_deliveries?id=eq.${deliveryId}&status=eq.processing`,
      { status, message_id, updated_at: new Date().toISOString() },
      "PATCH",
    );
    if (!r.ok) throw Error("Falha no registro do resultado");
  };
  try {
    const authorization = req.headers.get("Authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) {
      return reply({ error: "Entre na sua conta." }, 401);
    }
    const identity = await fetch(url + "/auth/v1/user", {
      headers: {
        apikey: Deno.env.get("SUPABASE_ANON_KEY")!,
        Authorization: authorization,
      },
      signal: AbortSignal.timeout(15000),
    });
    if (!identity.ok) return reply({ error: "Sessão inválida." }, 401);
    const actor = await identity.json();
    const body = await req.json();
    if (
      typeof body.id !== "string" || !/^[0-9a-f-]{36}$/i.test(body.id) ||
      !Number.isInteger(body.version) || body.version < 1
    ) return reply({ error: "Ocorrência inválida." }, 400);
    const gmailText = Deno.env.get("GMAIL_OAUTH");
    if (!gmailText) {
      return reply(
        { error: "O administrador precisa configurar o Gmail." },
        503,
      );
    }
    const gmail = JSON.parse(gmailText);
    const claimed = await rest("rpc/claim_occurrence_email", {
      p_id: body.id,
      p_version: body.version,
      p_actor: actor.id,
    });
    if (!claimed.ok) {
      return reply({
        error: claimed.data?.code === "P0001"
          ? claimed.data.message
          : "Não foi possível preparar o envio.",
      }, 403);
    }
    const claim = claimed.data;
    if (!claim.send) {
      return reply({ status: claim.delivery.status, id: claim.delivery.id });
    }
    deliveryId = claim.delivery.id;
    const pdf = await canonicalPdf(claim.occurrence);
    const mime = mimeMessage(
      gmail.sender,
      claim.delivery.recipients,
      deliveryId!,
      pdf,
    );
    const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: gmail.client_id,
        client_secret: gmail.client_secret,
        refresh_token: gmail.refresh_token,
        grant_type: "refresh_token",
      }),
      signal: AbortSignal.timeout(15000),
    });
    const token = await tokenResponse.json();
    if (!tokenResponse.ok || !token.access_token) {
      throw Error("OAuth indisponível");
    }
    sending = true;
    const sent = await fetch(
      "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token.access_token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          raw: base64(new TextEncoder().encode(mime)).replace(/\+/g, "-")
            .replace(/\//g, "_").replace(/=+$/, ""),
        }),
        signal: AbortSignal.timeout(20000),
      },
    );
    if (!sent.ok) {
      // Uma rejeição explícita 4xx é recuperável; falhas 5xx podem ter ocorrido após aceitação.
      const status = sent.status >= 500 ? "unknown" : "failed";
      await finish(status);
      return reply({
        status,
        error: status === "unknown"
          ? "Resultado incerto. Confira o Gmail antes de reenviar."
          : "O Gmail recusou o envio. Peça ao admin para conferir a configuração.",
      }, 502);
    }
    const result = await sent.json();
    if (!result.id) throw Error("Sem confirmação");
    await finish("sent", result.id);
    return reply({ status: "sent", id: deliveryId });
  } catch (_) {
    if (deliveryId) {
      try {
        await finish(sending ? "unknown" : "failed");
      } catch (_) {
        /* Processing permanece bloqueado para evitar duplicação. */
      }
    }
    return reply({
      status: sending ? "unknown" : "failed",
      error: sending
        ? "Resultado incerto. Confira o Gmail antes de reenviar."
        : "Envio não concluído. Confira a configuração do Gmail.",
    }, 502);
  }
}
export default { fetch: handler };
