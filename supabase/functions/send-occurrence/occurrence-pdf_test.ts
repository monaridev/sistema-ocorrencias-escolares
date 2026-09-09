import { PDFDocument } from "npm:pdf-lib@1.17.1";
import { canonicalPdf } from "./occurrence-pdf.ts";
import cases from "../../../v2-mobile/test/fixtures/pdf_v1.json" with {
  type: "json",
};
for (const [name, record] of Object.entries(cases)) {
  Deno.test(`Modelo V1: ${name}`, async () => {
    const bytes = await canonicalPdf(record, new Date("2026-09-09T15:00:00Z"));
    const doc = await PDFDocument.load(bytes);
    const expected = name === "limites" || name === "cancelada" ? 2 : 1;
    if (doc.getPageCount() !== expected) {
      throw Error(`Paginação inesperada: ${name}`);
    }
    const dir = Deno.env.get("PDF_QA_DIR");
    if (dir) {
      await Deno.mkdir(dir, { recursive: true });
      await Deno.writeFile(`${dir}/server-${name}.pdf`, bytes);
    }
  });
}
