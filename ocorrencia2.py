"""
=============================================================
  FICHA DE OCORRÊNCIA DISCIPLINAR
  E.E. João Paulo II — Mauá/SP
=============================================================
  Dependências:
    pip install customtkinter reportlab

  Configuração de E-mail:
    Edite o bloco "CONFIGURAÇÕES DE EMAIL" abaixo com:
    - EMAIL_REMETENTE : conta Gmail que vai ENVIAR
    - SENHA_APP       : senha de app gerada no Gmail
                        (Conta Google → Segurança → Senhas de app)
    - EMAIL_DESTINO   : e-mail FIXO que vai RECEBER as ocorrências
=============================================================
"""

import customtkinter as ctk
from tkinter import messagebox
import smtplib
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from datetime import datetime

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.pdfgen import canvas as rl_canvas
from reportlab.lib import colors

# ─────────────────────────────────────────────
#   CONFIGURAÇÕES DE EMAIL
# ─────────────────────────────────────────────
#
#   1. Seguinte Fernando, ao invés de usar sempre um email de professor, que que eu pensei
#      Você vai criar um email especializado para a escola, somenta para armazenar as ocorrências
#      tipo "ocorrencias.jpII@gmail.com", ai ao inves de ter que sempre ficar alternando,  mantem um fixo de remetente e destino
#      Deixando claro que o email_destino é pra voce por algum email final, que vai receber os pdf para imprimir, porque precisa por assinatura do responsavel
#      
#
#   2. A senha_app, vo deixa um tutorial de como se vai gerar, eu sei que voce já sabe mas é sempre bom 
#      Acessa o myaccount.google.com / vai em Segurança / Vai em 2 etapa, e ativa ela nesse email que voce criou
#      / Ai depois se volta, e pesquisa ali na barrinha mesmo "Senhas de app", ai voce abre, cria uma
#      O nome pode ser "ocorrencia", ou o que se preferir, não tem importancia, ai depois que você criar
#      Ele vai te entregar uma senha pique "xxxx xxxx xxxx xxxx", se copia ela e mete aqui em baixo nesse senha_app
#
#   3. Preencha as três linhas abaixo:
#
EMAIL_REMETENTE = "anonysettings@gmail.com"
SENHA_APP       = "gvzv zjlr fqwr yyjb "
EMAIL_DESTINO   = "diogomonarifigueiredo@gmail.com"
# ─────────────────────────────────────────────

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")


# ══════════════════════════════════════════════
#   GERADOR DE PDF
# ══════════════════════════════════════════════
def gerar_pdf(dados: dict) -> str:
    aluno_nome = dados["aluno"].replace(" ", "_")
    timestamp  = datetime.now().strftime("%Y%m%d_%H%M%S")
    nome_arq   = f"Ocorrencia_{aluno_nome}_{timestamp}.pdf"

    c = rl_canvas.Canvas(nome_arq, pagesize=A4)
    w, h = A4  # 595 x 842 pts

    def linha_h(y, x1=1.5*cm, x2=w - 1.5*cm, cor=colors.HexColor("#CCCCCC")):
        c.setStrokeColor(cor)
        c.line(x1, y, x2, y)

    def txt(texto, x, y, tamanho=10, bold=False, cor=colors.black, align="left"):
        c.setFillColor(cor)
        c.setFont("Helvetica-Bold" if bold else "Helvetica", tamanho)
        if align == "center":
            c.drawCentredString(x, y, texto)
        else:
            c.drawString(x, y, texto)

    # ── Cabeçalho ──────────────────────────────
    c.setFillColor(colors.HexColor("#0A2C5E"))
    c.rect(0, h - 3.2*cm, w, 3.2*cm, fill=1, stroke=0)

    txt("SÃO PAULO – GOVERNO DO ESTADO",      w/2, h - 0.9*cm,  tamanho=11, bold=True,  cor=colors.white, align="center")
    txt("SECRETARIA DE ESTADO DA EDUCAÇÃO",   w/2, h - 1.5*cm,  tamanho=9,  cor=colors.HexColor("#B0C8F0"), align="center")
    txt("DIRETORIA DE ENSINO REGIÃO DE MAUÁ", w/2, h - 2.0*cm,  tamanho=9,  cor=colors.HexColor("#B0C8F0"), align="center")
    txt("ESCOLA ESTADUAL EE JOÃO PAULO II",   w/2, h - 2.5*cm,  tamanho=9,  cor=colors.HexColor("#B0C8F0"), align="center")
    txt("Rua Barnabé Costa, 57 – Campo Verde – Mauá – SP – CEP 09320-015 | (11) 4514-7259",
        w/2, h - 3.0*cm, tamanho=7.5, cor=colors.HexColor("#90B0E0"), align="center")

    # ── Título da ficha ─────────────────────────
    cy = h - 4.0*cm
    c.setFillColor(colors.HexColor("#F0F4FF"))
    c.rect(1.5*cm, cy - 0.6*cm, w - 3*cm, 0.9*cm, fill=1, stroke=0)
    txt("FICHA DE OCORRÊNCIA DISCIPLINAR", w/2, cy - 0.25*cm, tamanho=13, bold=True,
        cor=colors.HexColor("#0A2C5E"), align="center")

    # ── Identificação ───────────────────────────
    cy -= 1.5*cm
    txt("IDENTIFICAÇÃO", 1.5*cm, cy, tamanho=9, bold=True, cor=colors.HexColor("#0A2C5E"))
    linha_h(cy - 0.15*cm, cor=colors.HexColor("#0A2C5E"))

    cy -= 0.7*cm
    txt("Nome do Aluno:", 1.5*cm, cy, tamanho=9, bold=True)
    txt(dados["aluno"],  4.5*cm, cy, tamanho=9)
    txt("Série:", w - 6*cm, cy, tamanho=9, bold=True)
    txt(dados["serie"],  w - 4.8*cm, cy, tamanho=9)

    cy -= 0.65*cm
    txt("Data:", 1.5*cm, cy, tamanho=9, bold=True)
    txt(dados["data"],  2.8*cm, cy, tamanho=9)
    txt("Relatado por:", 7*cm, cy, tamanho=9, bold=True)
    txt(dados["relatado_por"], 10*cm, cy, tamanho=9)

    # ── Ocorrências ─────────────────────────────
    cy -= 1.0*cm
    txt("OCORRÊNCIA", 1.5*cm, cy, tamanho=9, bold=True, cor=colors.HexColor("#0A2C5E"))
    linha_h(cy - 0.15*cm, cor=colors.HexColor("#0A2C5E"))

    ocorrencias = [
        ("oc1",  "Portar materiais e/ou equipamentos não pertencentes à aula"),
        ("oc2",  "Usar celular durante a aula"),
        ("oc3",  "Não portar os materiais mínimos necessários à aula"),
        ("oc4",  "Não realizar as atividades propostas durante a aula"),
        ("oc5",  "Sair sem autorização do professor da sala de aula"),
        ("oc6",  "Não retornar e/ou ficar fora da sala de aula"),
        ("oc7",  "Desacato a gestores/professores ou funcionários"),
        ("oc8",  "Indisciplina considerada grave"),
        ("oc9",  "Depredar o patrimônio público"),
        ("oc10", "Prejudicar o andamento da aula"),
        ("oc11", "Outra"),
    ]

    cy -= 0.5*cm
    for chave, rotulo in ocorrencias:
        marcado = dados.get(chave, False)
        # caixa do checkbox
        c.setStrokeColor(colors.HexColor("#0A2C5E"))
        c.setFillColor(colors.HexColor("#0A2C5E") if marcado else colors.white)
        c.rect(1.5*cm, cy - 0.22*cm, 0.32*cm, 0.32*cm, fill=1, stroke=1)
        if marcado:
            c.setFillColor(colors.white)
            c.setFont("Helvetica-Bold", 8)
            c.drawString(1.56*cm, cy - 0.16*cm, "✓")
        txt(rotulo, 2.1*cm, cy, tamanho=9)
        cy -= 0.52*cm

    # campo "Outra" descrição
    if dados.get("outra_desc", "").strip():
        txt(f"   → {dados['outra_desc']}", 2.1*cm, cy, tamanho=8.5, cor=colors.HexColor("#333333"))
        cy -= 0.52*cm

    # ── Relato ──────────────────────────────────
    cy -= 0.4*cm
    txt("RELATO DA OCORRÊNCIA", 1.5*cm, cy, tamanho=9, bold=True, cor=colors.HexColor("#0A2C5E"))
    linha_h(cy - 0.15*cm, cor=colors.HexColor("#0A2C5E"))

    cy -= 0.5*cm
    relato = dados.get("relato", "").strip()
    # quebra manual do relato em linhas de ~90 chars
    palavras = relato.split()
    linhas, linha_atual = [], ""
    for p in palavras:
        if len(linha_atual) + len(p) + 1 <= 90:
            linha_atual += (" " if linha_atual else "") + p
        else:
            linhas.append(linha_atual)
            linha_atual = p
    if linha_atual:
        linhas.append(linha_atual)

    # garante ao menos 4 linhas para impressão
    while len(linhas) < 4:
        linhas.append("")

    for lh in linhas[:8]:
        txt(lh, 1.5*cm, cy, tamanho=9)
        c.setStrokeColor(colors.HexColor("#CCCCCC"))
        c.line(1.5*cm, cy - 0.15*cm, w - 1.5*cm, cy - 0.15*cm)
        cy -= 0.55*cm

    # ── Providências ────────────────────────────
    cy -= 0.5*cm
    txt("PROVIDÊNCIA TOMADA PELA EQUIPE GESTORA", 1.5*cm, cy, tamanho=9, bold=True,
        cor=colors.HexColor("#0A2C5E"))
    linha_h(cy - 0.15*cm, cor=colors.HexColor("#0A2C5E"))

    providencias = [
        ("pv1", "Admoestação verbal"),
        ("pv2", "Registro em livro de Ocorrência"),
        ("pv3", "Convocação do pai ou responsável à U.E."),
        ("pv4", "Encaminhamento ao Conselho de Escola"),
        ("pv5", "Pedir trabalho de pesquisa, escrito à mão, sobre a lei que se aplica a tal ocorrência"),
        ("pv6", "Outra"),
    ]

    cy -= 0.5*cm
    for chave, rotulo in providencias:
        marcado = dados.get(chave, False)
        c.setStrokeColor(colors.HexColor("#0A2C5E"))
        c.setFillColor(colors.HexColor("#0A2C5E") if marcado else colors.white)
        c.rect(1.5*cm, cy - 0.22*cm, 0.32*cm, 0.32*cm, fill=1, stroke=1)
        if marcado:
            c.setFillColor(colors.white)
            c.setFont("Helvetica-Bold", 8)
            c.drawString(1.56*cm, cy - 0.16*cm, "✓")
        txt(rotulo, 2.1*cm, cy, tamanho=9)
        cy -= 0.52*cm

    # ── Campos finais ───────────────────────────
    cy -= 0.6*cm
    linha_h(cy + 0.3*cm, cor=colors.HexColor("#0A2C5E"))

    txt("Registro no Livro de Ata de Ocorrências — Página Nº: ", 1.5*cm, cy, tamanho=9, bold=True)
    txt(dados.get("pag_ata", ""), 11.5*cm, cy, tamanho=9)
    cy -= 0.6*cm
    txt("Ocorrência Atendida por: ", 1.5*cm, cy, tamanho=9, bold=True)
    txt(dados.get("atendida_por", ""), 6.0*cm, cy, tamanho=9)
    cy -= 0.6*cm
    txt("Ciência do Responsável: ", 1.5*cm, cy, tamanho=9, bold=True)
    txt(dados.get("ciencia_resp", ""), 6.0*cm, cy, tamanho=9)

    # ── Assinaturas ─────────────────────────────
    cy -= 1.4*cm
    linha_h(cy + 0.3*cm, cor=colors.HexColor("#CCCCCC"))

    assinaturas = [
        (1.5*cm,       "Assinatura do Aluno"),
        (w/2 - 3.5*cm, "Assinatura do Responsável"),
        (w - 7.5*cm,   "Assinatura da Equipe Gestora"),
    ]
    for ax, label in assinaturas:
        c.setStrokeColor(colors.HexColor("#555555"))
        c.line(ax, cy, ax + 5.5*cm, cy)
        txt(label, ax, cy - 0.4*cm, tamanho=7.5, cor=colors.HexColor("#555555"))

    # ── Rodapé ──────────────────────────────────
    c.setFillColor(colors.HexColor("#0A2C5E"))
    c.rect(0, 0, w, 0.7*cm, fill=1, stroke=0)
    gerado_em = datetime.now().strftime("%d/%m/%Y às %H:%M")
    txt(f"Documento gerado em {gerado_em}  |  e038453a@educacao.sp.gov.br",
        w/2, 0.22*cm, tamanho=7, cor=colors.HexColor("#90B0E0"), align="center")

    c.save()
    return nome_arq


# ══════════════════════════════════════════════
#   ENVIO DE EMAIL
# ══════════════════════════════════════════════
def enviar_email(caminho_pdf: str, aluno: str, data: str) -> bool:
    try:
        msg = MIMEMultipart()
        msg["From"]    = EMAIL_REMETENTE
        msg["To"]      = EMAIL_DESTINO
        msg["Subject"] = f"[Ocorrência] {aluno} — {data}"

        corpo = (
            f"Prezada Equipe Gestora,\n\n"
            f"Segue em anexo a Ficha de Ocorrência Disciplinar do(a) aluno(a) "
            f"<b>{aluno}</b>, registrada em {data}.\n\n"
            f"O documento foi gerado automaticamente pelo sistema de ocorrências "
            f"da E.E. João Paulo II.\n\n"
            f"Atenciosamente,\nSistema de Ocorrências"
        )
        msg.attach(MIMEText(corpo, "plain", "utf-8"))

        with open(caminho_pdf, "rb") as f:
            parte = MIMEBase("application", "octet-stream")
            parte.set_payload(f.read())
        encoders.encode_base64(parte)
        parte.add_header("Content-Disposition", f'attachment; filename="{os.path.basename(caminho_pdf)}"')
        msg.attach(parte)

        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as servidor:
            servidor.login(EMAIL_REMETENTE, SENHA_APP)
            servidor.sendmail(EMAIL_REMETENTE, EMAIL_DESTINO, msg.as_string())

        return True
    except Exception as e:
        messagebox.showerror("Erro ao enviar e-mail", str(e))
        return False


# ══════════════════════════════════════════════
#   INTERFACE GRÁFICA (CustomTkinter)
# ══════════════════════════════════════════════
class App(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Ficha de Ocorrência Disciplinar — E.E. João Paulo II")
        self.geometry("720x900")
        self.resizable(True, True)
        self._build_ui()
        # Correção de scroll do mouse no CTkScrollableFrame
        self.bind_all("<MouseWheel>", self._scroll_mouse)

    def _scroll_mouse(self, event):
        """Redireciona scroll do mouse para o CTkScrollableFrame."""
        try:
            self.scroll._parent_canvas.yview_scroll(
                int(-1 * (event.delta / 120)), "units"
            )
        except Exception:
            pass

    # ── Helpers de layout ──────────────────────
    def _secao(self, pai, titulo: str) -> ctk.CTkFrame:
        frame = ctk.CTkFrame(pai, corner_radius=10)
        frame.pack(fill="x", padx=18, pady=(0, 10))
        ctk.CTkLabel(frame, text=titulo, font=ctk.CTkFont(size=12, weight="bold"),
                     text_color="#7EB8F7").pack(anchor="w", padx=14, pady=(10, 4))
        return frame

    def _campo(self, pai, rotulo: str, largura: int = 300, valor_padrao: str = "") -> ctk.CTkEntry:
        linha = ctk.CTkFrame(pai, fg_color="transparent")
        linha.pack(fill="x", padx=14, pady=3)
        ctk.CTkLabel(linha, text=rotulo, width=160, anchor="w").pack(side="left")
        entry = ctk.CTkEntry(linha, width=largura)
        entry.insert(0, valor_padrao)
        entry.pack(side="left")
        return entry

    def _check(self, pai, texto: str, var: ctk.BooleanVar):
        ctk.CTkCheckBox(pai, text=texto, variable=var,
                        font=ctk.CTkFont(size=12)).pack(anchor="w", padx=22, pady=2)

    # ── Construção da UI ───────────────────────
    def _build_ui(self):
        # Scroll externo
        self.scroll = ctk.CTkScrollableFrame(self, corner_radius=0)
        self.scroll.pack(fill="both", expand=True, padx=0, pady=0)

        # Cabeçalho visual
        cab = ctk.CTkFrame(self.scroll, fg_color="#0A2C5E", corner_radius=0)
        cab.pack(fill="x", padx=0, pady=(0, 14))
        ctk.CTkLabel(cab, text="SÃO PAULO – GOVERNO DO ESTADO",
                     font=ctk.CTkFont(size=14, weight="bold"),
                     text_color="white").pack(pady=(12, 0))
        for sub in ["SECRETARIA DE ESTADO DA EDUCAÇÃO",
                    "DIRETORIA DE ENSINO REGIÃO DE MAUÁ",
                    "ESCOLA ESTADUAL EE JOÃO PAULO II"]:
            ctk.CTkLabel(cab, text=sub, font=ctk.CTkFont(size=11),
                         text_color="#B0C8F0").pack()
        ctk.CTkLabel(cab, text="FICHA DE OCORRÊNCIA DISCIPLINAR",
                     font=ctk.CTkFont(size=13, weight="bold"),
                     text_color="#FFD700").pack(pady=(6, 12))

        # ── 1. Identificação ─────────────────────
        f_id = self._secao(self.scroll, "📋  Identificação")
        self.entry_aluno       = self._campo(f_id, "Nome do Aluno:", 300)
        self.entry_serie       = self._campo(f_id, "Série / Turma:", 100)
        self.entry_data        = self._campo(f_id, "Data:", 120,
                                             datetime.now().strftime("%d/%m/%Y"))
        self.entry_relatado    = self._campo(f_id, "Relatado por:", 260)

        # ── 2. Ocorrências ───────────────────────
        f_oc = self._secao(self.scroll, "⚠️  Ocorrência")
        self.vars_oc = {}
        ocorrencias = [
            ("oc1",  "Portar materiais e/ou equipamentos não pertencentes à aula"),
            ("oc2",  "Usar celular durante a aula"),
            ("oc3",  "Não portar os materiais mínimos necessários à aula"),
            ("oc4",  "Não realizar as atividades propostas durante a aula"),
            ("oc5",  "Sair sem autorização do professor da sala de aula"),
            ("oc6",  "Não retornar e/ou ficar fora da sala de aula"),
            ("oc7",  "Desacato a gestores/professores ou funcionários"),
            ("oc8",  "Indisciplina considerada grave"),
            ("oc9",  "Depredar o patrimônio público"),
            ("oc10", "Prejudicar o andamento da aula"),
            ("oc11", "Outra"),
        ]
        for chave, texto in ocorrencias:
            v = ctk.BooleanVar()
            self.vars_oc[chave] = v
            self._check(f_oc, texto, v)

        # campo "Outra" descrição
        linha_outra = ctk.CTkFrame(f_oc, fg_color="transparent")
        linha_outra.pack(fill="x", padx=30, pady=(0, 8))
        ctk.CTkLabel(linha_outra, text="Se 'Outra', descreva:", width=160, anchor="w").pack(side="left")
        self.entry_outra = ctk.CTkEntry(linha_outra, width=350)
        self.entry_outra.pack(side="left")

        # ── 3. Relato ────────────────────────────
        f_rel = self._secao(self.scroll, "📝  Relato da Ocorrência")
        self.text_relato = ctk.CTkTextbox(f_rel, height=110, corner_radius=6)
        self.text_relato.pack(fill="x", padx=14, pady=(0, 10))

        # ── 4. Providências ──────────────────────
        f_pv = self._secao(self.scroll, "🛡️  Providência Tomada pela Equipe Gestora")
        self.vars_pv = {}
        providencias = [
            ("pv1", "Admoestação verbal"),
            ("pv2", "Registro em livro de Ocorrência"),
            ("pv3", "Convocação do pai ou responsável à U.E."),
            ("pv4", "Encaminhamento ao Conselho de Escola"),
            ("pv5", "Pedir trabalho de pesquisa sobre a lei aplicável"),
            ("pv6", "Outra"),
        ]
        for chave, texto in providencias:
            v = ctk.BooleanVar()
            self.vars_pv[chave] = v
            self._check(f_pv, texto, v)

        # ── 5. Campos finais ─────────────────────
        f_fin = self._secao(self.scroll, "📖  Registro Final")
        self.entry_pag_ata     = self._campo(f_fin, "Pág. no Livro de Ata:", 80)
        self.entry_atendida    = self._campo(f_fin, "Ocorrência atendida por:", 260)
        self.entry_ciencia     = self._campo(f_fin, "Ciência do Responsável:", 260)

        # ── Botão ────────────────────────────────
        ctk.CTkButton(
            self.scroll,
            text="📄  GERAR PDF E ENVIAR POR E-MAIL",
            font=ctk.CTkFont(size=13, weight="bold"),
            height=48,
            corner_radius=10,
            fg_color="#0A2C5E",
            hover_color="#1A4C8E",
            command=self._confirmar_e_enviar
        ).pack(padx=18, pady=16)

    # ── Ação do botão ──────────────────────────
    def _confirmar_e_enviar(self):
        aluno = self.entry_aluno.get().strip()
        if not aluno:
            messagebox.showwarning("Atenção", "Informe o nome do aluno antes de continuar.")
            return

        resposta = messagebox.askyesno(
            "Confirmar",
            f"Deseja gerar e enviar a ocorrência de\n\n"
            f"Aluno: {aluno}\n"
            f"Data:  {self.entry_data.get()}\n\n"
            f"O PDF será enviado para:\n{EMAIL_DESTINO}"
        )
        if not resposta:
            return

        dados = {
            "aluno":        aluno,
            "serie":        self.entry_serie.get().strip(),
            "data":         self.entry_data.get().strip(),
            "relatado_por": self.entry_relatado.get().strip(),
            "relato":       self.text_relato.get("1.0", "end").strip(),
            "outra_desc":   self.entry_outra.get().strip(),
            "pag_ata":      self.entry_pag_ata.get().strip(),
            "atendida_por": self.entry_atendida.get().strip(),
            "ciencia_resp": self.entry_ciencia.get().strip(),
        }
        dados.update({k: v.get() for k, v in self.vars_oc.items()})
        dados.update({k: v.get() for k, v in self.vars_pv.items()})

        try:
            pdf_path = gerar_pdf(dados)
        except Exception as e:
            messagebox.showerror("Erro ao gerar PDF", str(e))
            return

        ok = enviar_email(pdf_path, aluno, dados["data"])
        if ok:
            messagebox.showinfo(
                "Sucesso! ✅",
                f"PDF gerado e enviado com sucesso!\n\n"
                f"Arquivo: {pdf_path}\n"
                f"Enviado para: {EMAIL_DESTINO}"
            )
            os.startfile(os.getcwd())   # abre a pasta (Windows)
        else:
            messagebox.showwarning(
                "PDF gerado, mas e-mail falhou",
                f"O PDF foi salvo em:\n{pdf_path}\n\n"
                "Verifique as configurações de e-mail no topo do arquivo."
            )


# ══════════════════════════════════════════════
if __name__ == "__main__":
    app = App()
    app.mainloop()
