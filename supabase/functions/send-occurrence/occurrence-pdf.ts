import { PDFDocument, rgb, StandardFonts } from "npm:pdf-lib@1.17.1";
import { actions, logoSp, reasons } from "./v1-assets.ts";

export type RecordData = {
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

// Portar as coordenadas de gerar_pdf da V1; manter o par Flutter em sincronia.
export async function canonicalPdf(o: RecordData, generatedAt = new Date()) {
  const doc = await PDFDocument.create();
  doc.setTitle("Ficha de ocorrência disciplinar");
  doc.setSubject(`Registro ${o.id} | Versão ${o.version}`);
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const logo = await doc.embedPng(logoSp);
  const cm = 72 / 2.54, w = 21 * cm, h = 29.7 * cm;
  const blue = "0A2C5E";
  const color = (hex: string) =>
    rgb(
      parseInt(hex.slice(0, 2), 16) / 255,
      parseInt(hex.slice(2, 4), 16) / 255,
      parseInt(hex.slice(4, 6), 16) / 255,
    );
  let page = doc.addPage([w, h]);
  const width = (s: string, size = 9, strong = false) =>
    Array.from(s).reduce(
      (sum, char) => sum + (strong ? bold : font).widthOfTextAtSize(char, size),
      0,
    );
  const text = (
    s: string,
    x: number,
    y: number,
    size = 9,
    strong = false,
    ink = "000000",
    center = false,
  ) => {
    page.drawText(s, {
      x: center ? x - width(s, size, strong) / 2 : x,
      y,
      size,
      font: strong ? bold : font,
      color: color(ink),
    });
  };
  const line = (y: number, ink = "CCCCCC", x = 1.5 * cm, end = w - 1.5 * cm) =>
    page.drawLine({
      start: { x, y },
      end: { x: end, y },
      thickness: 1,
      color: color(ink),
    });
  const rect = (
    x: number,
    y: number,
    rw: number,
    rh: number,
    fill: string,
    border?: string,
  ) =>
    page.drawRectangle({
      x,
      y,
      width: rw,
      height: rh,
      color: color(fill),
      borderColor: border ? color(border) : undefined,
      borderWidth: border ? 1 : 0,
    });
  const wrap = (s: string, max: number, size = 9): string[] => {
    const rows: string[] = [];
    let row = "";
    for (const word of s.trim().split(/\s+/).filter(Boolean)) {
      const trial = row ? row + " " + word : word;
      if (width(trial, size) <= max) {
        row = trial;
        continue;
      }
      if (row) {
        rows.push(row);
        row = "";
      }
      for (const char of word) {
        if (width(row + char, size) > max) {
          rows.push(row);
          row = "";
        }
        row += char;
      }
    }
    if (row) rows.push(row);
    return rows;
  };
  const extra: { title: string; rows: string[] }[] = [];
  const fitted = (
    label: string,
    value: string,
    x: number,
    y: number,
    size = 9,
  ) => {
    const rows = wrap(value, w - 1.5 * cm - x, size);
    if (rows.length > 1) {
      text("Ver continuação", x, y, size);
      extra.push({ title: label, rows: wrap(value, w - 3 * cm) });
    } else text(rows[0] ?? "", x, y, size);
  };
  const header = () => {
    rect(0, h - 3.4 * cm, w, 3.4 * cm, "FFFFFF");
    line(h - 3.3 * cm);
    const lh = 2.2 * cm, lw = lh * logo.width / logo.height;
    page.drawImage(logo, {
      x: 1.5 * cm,
      y: h - 3.1 * cm,
      width: lw,
      height: lh,
    });
    const x = 1.5 * cm + lw + .4 * cm;
    text("SECRETARIA DE ESTADO DA EDUCAÇÃO", x, h - 1.1 * cm, 10, true);
    text("UNIDADE REGIONAL DE ENSINO DE MAUÁ", x, h - 1.65 * cm);
    text("ESCOLA ESTADUAL E.E. JOÃO PAULO II", x, h - 2.15 * cm);
    text(
      "Rua Barnabé Costa, 57 – Campo Verde – Mauá – SP – CEP 09320-015",
      x,
      h - 2.65 * cm,
      7.5,
      false,
      "555555",
    );
    text(
      "Fone: (11) 4514-7259  –  E-mail: e038453a@educacao.sp.gov.br",
      x,
      h - 3.1 * cm,
      7.5,
      false,
      "555555",
    );
    if (o.status === "cancelled") {
      text("CANCELADA", w - 4 * cm, h - .55 * cm, 10, true, "B00020");
    }
  };
  const parts = new Intl.DateTimeFormat("pt-BR", {
    timeZone: "America/Sao_Paulo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(generatedAt);
  const part = (key: string) => parts.find((p) => p.type === key)!.value;
  const timestamp = `${part("day")}/${part("month")}/${part("year")} às ${
    part("hour")
  }:${part("minute")}`;
  const footer = () => {
    rect(0, 0, w, .7 * cm, blue);
    text(
      `Documento gerado em ${timestamp}  |  e038453a@educacao.sp.gov.br`,
      w / 2,
      .22 * cm,
      7,
      false,
      "90B0E0",
      true,
    );
  };
  header();
  let y = h - 4.2 * cm;
  rect(1.5 * cm, y - .5 * cm, w - 3 * cm, .85 * cm, "FFFFFF", "1A1A1A");
  text(
    "FICHA DE OCORRÊNCIA DISCIPLINAR",
    w / 2,
    y - .2 * cm,
    12,
    true,
    "1A1A1A",
    true,
  );
  const section = (title: string) => {
    text(title, 1.5 * cm, y, 9, true, blue);
    line(y - .15 * cm, blue);
  };
  y -= 1.3 * cm;
  section("IDENTIFICAÇÃO");
  y -= .7 * cm;
  for (
    const [label, value, x] of [
      ["Nome do Aluno: ", o.students.nome, 4.1],
      ["Série: ", o.students.turma, 2.5],
      ["Data: ", o.occurrence_date.split("-").reverse().join("/"), 2.4],
      ["Relatado por: ", o.professor, 3.7],
    ] as const
  ) {
    text(label, 1.5 * cm, y, 9, true);
    fitted(label, value, x * cm, y);
    y -= .52 * cm;
  }
  y += .52 * cm;
  y -= 1 * cm;
  section("OCORRÊNCIA");
  y -= .5 * cm;
  const checkbox = (label: string, checked: boolean) => {
    rect(
      1.5 * cm,
      y - .06 * cm,
      .28 * cm,
      .28 * cm,
      checked ? blue : "FFFFFF",
      blue,
    );
    if (checked) text("X", 1.53 * cm, y - .01 * cm, 7, true, "FFFFFF");
    text(label, 1.93 * cm, y);
    y -= .52 * cm;
  };
  const other = o.motivos.filter((r) => !reasons.slice(0, -1).includes(r));
  for (const reason of reasons) {
    checkbox(
      reason,
      reason === "Outro" ? other.length > 0 : o.motivos.includes(reason),
    );
  }
  const otherText = other.map((r) => r.replace(/^Outro\s*:?\s*/, "")).filter(
    Boolean,
  ).join("; ");
  if (otherText) {
    // Seta vetorial: a mesma marca da V1 sem depender de glifo ausente em Helvetica.
    const ax = 2.35 * cm, ay = y + .07 * cm;
    line(ay, "333333", ax, ax + .25 * cm);
    page.drawLine({
      start: { x: ax + .25 * cm, y: ay },
      end: { x: ax + .16 * cm, y: ay + .06 * cm },
      thickness: 1,
      color: color("333333"),
    });
    page.drawLine({
      start: { x: ax + .25 * cm, y: ay },
      end: { x: ax + .16 * cm, y: ay - .06 * cm },
      thickness: 1,
      color: color("333333"),
    });
    fitted("Outro motivo", otherText, 2.75 * cm, y, 8.5);
    y -= .52 * cm;
  }
  y -= .4 * cm;
  section("RELATO DA OCORRÊNCIA");
  y -= .5 * cm;
  const report = wrap(o.relato, w - 3 * cm);
  // A V1 desenha no mínimo quatro e no máximo oito linhas de relato.
  const maxRows = 8;
  const shown = report.length > maxRows
    ? ["Ver relato integral na continuação."]
    : [...report];
  if (report.length > maxRows) {
    extra.push({ title: "RELATO DA OCORRÊNCIA", rows: report });
  }
  while (shown.length < 4) shown.push("");
  for (const row of shown) {
    text(row, 1.5 * cm, y);
    line(y - .15 * cm);
    y -= .55 * cm;
  }
  y -= .5 * cm;
  section("PROVIDÊNCIA TOMADA PELA EQUIPE GESTORA");
  y -= .5 * cm;
  const unknownActions = o.providencias.filter((a) => !actions.includes(a));
  for (const action of actions) {
    checkbox(
      action,
      o.providencias.includes(action) ||
        (action === "Outra" && unknownActions.length > 0),
    );
  }
  if (unknownActions.length) {
    extra.push({
      title: "Outras providências",
      rows: wrap(unknownActions.join("; "), w - 3 * cm),
    });
  }
  y -= .6 * cm;
  line(y + .3 * cm, blue);
  text(
    "Registro no Livro de Ata de Ocorrências — Página Nº: ",
    1.5 * cm,
    y,
    9,
    true,
  );
  y -= .6 * cm;
  text("Ocorrência Atendida por: ", 1.5 * cm, y, 9, true);
  y -= .6 * cm;
  text("Ciência do Responsável: ", 1.5 * cm, y, 9, true);
  y -= 1.4 * cm;
  line(y + .3 * cm);
  for (
    const [x, label] of [[1.5 * cm, "Assinatura do Aluno"], [
      w / 2 - 3.5 * cm,
      "Assinatura do Responsável",
    ], [w - 7.5 * cm, "Assinatura da Equipe Gestora"]] as const
  ) {
    line(y, "555555", x, x + 5.5 * cm);
    text(label, x, y - .4 * cm, 7.5, false, "555555");
  }
  footer();
  if (o.status === "cancelled" && o.change_reason) {
    extra.push({
      title: "Justificativa do cancelamento",
      rows: wrap(o.change_reason, w - 3 * cm),
    });
  }
  let number = 1;
  const continuation = () => {
    page = doc.addPage([w, h]);
    header();
    footer();
    y = h - 4.2 * cm;
    section(`FICHA DE OCORRÊNCIA DISCIPLINAR — CONTINUAÇÃO ${++number}`);
    y -= .65 * cm;
    text(`Registro ${o.id} | Versão ${o.version}`, 1.5 * cm, y, 8);
    y -= .8 * cm;
  };
  for (const block of extra) {
    if (number === 1 || y < 3 * cm) continuation();
    section(block.title);
    y -= .55 * cm;
    for (const row of block.rows) {
      if (y < 1.6 * cm) continuation();
      text(row, 1.5 * cm, y);
      line(y - .15 * cm);
      y -= .55 * cm;
    }
    y -= .5 * cm;
  }
  return doc.save();
}
