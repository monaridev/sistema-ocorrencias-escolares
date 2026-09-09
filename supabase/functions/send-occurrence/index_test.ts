import { canonicalPdf, handler, mimeMessage } from "./index.ts";
function assert(value: unknown, message = "Falha") {
  if (!value) throw Error(message);
}
const record = {
  id: "10000000-0000-0000-0000-000000000001",
  version: 1,
  status: "cancelled",
  students: { nome: "João", turma: "2º B" },
  professor: "Márcia",
  occurrence_date: "2026-09-08",
  motivos: ["Atraso"],
  relato: "Relato privado.",
  providencias: ["Orientação"],
  change_reason: "Teste",
};
Deno.test("PDF e MIME preservam acentos e bloqueiam injeção de cabeçalhos", async () => {
  const pdf = await canonicalPdf(record);
  assert(new TextDecoder().decode(pdf.slice(0, 5)) === "%PDF-");
  const mime = mimeMessage(
    "school@example.com",
    ["test@example.com"],
    record.id,
    pdf,
  );
  assert(mime.includes("application/pdf"));
  assert(mime.includes("To: test@example.com"));
  let rejected = false;
  try {
    mimeMessage(
      "school@example.com",
      ["test@example.com\r\nBcc: other@example.com"],
      record.id,
      pdf,
    );
  } catch (_) {
    rejected = true;
  }
  assert(rejected);
  if (Deno.env.get("EMAIL_PDF_QA_OUTPUT")) {
    await Deno.writeFile(Deno.env.get("EMAIL_PDF_QA_OUTPUT")!, pdf);
  }
});
Deno.test("Anônimo não aciona Gmail", async () => {
  assert(
    (await handler(new Request("http://local", { method: "POST", body: "{}" })))
      .status === 401,
  );
});
for (const result of ["sent", "rejected", "timeout", "already_sent"]) {
  Deno.test("Envio " + result + " mantém estado correto", async () => {
    const original = globalThis.fetch;
    const old = Deno.env.get("GMAIL_OAUTH");
    Deno.env.set(
      "GMAIL_OAUTH",
      JSON.stringify({
        sender: "school@example.com",
        client_id: "test",
        client_secret: "test",
        refresh_token: "test",
      }),
    );
    let status = "processing", calls = 0;
    try {
      globalThis.fetch = async (input, init) => {
        const url = String(input);
        let data: unknown = {};
        let code = 200;
        if (url.endsWith("/auth/v1/user")) {
          data = { id: "author" };
        } else if (url.includes("claim_occurrence_email")) {
          data = {
            send: result !== "already_sent",
            delivery: {
              id: record.id,
              status: "sent",
              recipients: ["test@example.com"],
            },
            occurrence: record,
          };
        } else if (url.includes("oauth2.googleapis.com")) {
          data = { access_token: "test" };
        } else if (url.includes("messages/send")) {
          calls++;
          if (result === "timeout") {
            throw new TypeError("Conexão interrompida");
          }
          if (result === "rejected") code = 403;
          else data = { id: "gmail-id" };
        } else if (url.includes("email_deliveries")) {
          status = JSON.parse(String(init?.body)).status;
          return new Response(null, { status: 204 });
        }
        return new Response(JSON.stringify(data), { status: code });
      };
      const response = await handler(
        new Request("http://local", {
          method: "POST",
          headers: { Authorization: "Bearer test" },
          body: JSON.stringify({
            id: record.id,
            version: 1,
            recipients: ["attacker@example.com"],
            pdf: "forged",
          }),
        }),
      );
      assert(calls === (result === "already_sent" ? 0 : 1));
      assert(
        status ===
          (result === "sent"
            ? "sent"
            : result === "rejected"
            ? "failed"
            : result === "timeout"
            ? "unknown"
            : "processing"),
      );
      assert(
        response.status ===
          (["sent", "already_sent"].includes(result) ? 200 : 502),
      );
    } finally {
      globalThis.fetch = original;
      if (old === undefined) Deno.env.delete("GMAIL_OAUTH");
      else Deno.env.set("GMAIL_OAUTH", old);
    }
  });
}
