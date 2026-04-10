"""
=============================================================
  FICHA DE OCORRÊNCIA DISCIPLINAR
  E.E. João Paulo II — Mauá/SP
=============================================================
  Dependências:
    pip install customtkinter reportlab pywhatkit

  Configuração de E-mail:
    - EMAIL_REMETENTE  =  Email que estará enviando as ocorrências ( Fixo também. )
    - SENHA_APP  =  senha de app gerada no Gmail  (Conta Google → Segurança → Senhas de app)
    - EMAIL_DESTINO  =  Email fixo para receber as ocorrências

  Configuração do Whatsapp:
    - WHATSAPP_ESCOLAR  =  Numero que vai receber as notificações
=============================================================
"""

import customtkinter as ctk
from tkinter import messagebox
import smtplib
import os
import base64 as _b64
import io
import pywhatkit
import tkinter as tk
from PIL import Image, ImageTk
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from datetime import datetime

from dotenv import load_dotenv

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.pdfgen import canvas as rl_canvas
from reportlab.lib import colors
from reportlab.lib.utils import ImageReader

# ─────────────────────────────────────────────
#   CONFIGURAÇÕES DE EMAIL 
# ─────────────────────────────────────────────

#   1. Seguinte Fernando, ao invés de usar sempre um email de professor, que que eu pensei
#      Você vai criar um email especializado para a escola, somenta para armazenar as ocorrências
#      tipo "ocorrencias.jpII@gmail.com", ai ao inves de ter que sempre ficar alternando,  mantem um fixo de remetente e destino
#      Deixando claro que o email_destino é pra voce por algum email final, que vai receber os pdf para imprimir, porque precisa por assinatura do responsavel


#   2. A senha_app, vo deixa um tutorial de como se vai gerar, eu sei que voce já sabe mas é sempre bom 
#      Acessa o myaccount.google.com / vai em Segurança / Vai em 2 etapa, e ativa ela nesse email que voce criou
#      / Ai depois se volta, e pesquisa ali na barrinha mesmo "Senhas de app", ai voce abre, cria uma
#      O nome pode ser "ocorrencia", ou o que se preferir, não tem importancia, ai depois que você criar
#      Ele vai te entregar uma senha pique "xxxx xxxx xxxx xxxx", se copia ela e mete aqui em baixo nesse senha_app

#   3. Preencha as três linhas abaixo:

load_dotenv()
EMAIL_REMETENTE = os.getenv("EMAIL_REMETENTE")
SENHA_APP = os.getenv("SENHA_APP")
EMAIL_DESTINO = os.getenv("EMAIL_DESTINO")

# ─────────────────────────────────────────────
#   CONFIGURAÇÃO DO NÚMERO DO WHATSAPP 
# ─────────────────────────────────────────────

WHATSAPP_ESCOLAR  =  "11964617542"

# ─────────────────────────────────────────────
#   LISTAS DE OCORRÊNCIAS E PROVIDÊNCIAS
#   Sâo usadas na UI do APP e também no PDF 
# ─────────────────────────────────────────────

OCORRENCIAS = [
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
    ("oc11", "Outro"),
]

PROVIDENCIAS = [
    ("pv1", "Admoestação verbal"),
    ("pv2", "Registro em livro de Ocorrência"),
    ("pv3", "Convocação do pai ou responsável à U.E."),
    ("pv4", "Encaminhamento ao Conselho de Escola"),
    ("pv5", "Pedir trabalho de pesquisa sobre a lei aplicável"),
    ("pv6", "Outra"),
]

# ─────────────────────────────────────────────

# Logo SP oficial (embutido)
LOGO_SP_B64 = "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"

ctk.set_appearance_mode("light")
ctk.set_default_color_theme("blue")


# ══════════════════════════════════════════════
#   GERADOR DE PDF
# ══════════════════════════════════════════════
def gerar_pdf(dados: dict) -> str:

    aluno_nome = dados["aluno"].replace(" ", "_")
    timestamp  = datetime.now().strftime("%Y%m%d_%H%M%S")
    nome_arq   = f"Ocorrencia_{aluno_nome}_{timestamp}.pdf"

    pasta_docs = os.path.join(os.path.expanduser("~"), "Documents", "Ocorrencias_JPII")
    os.makedirs(pasta_docs, exist_ok=True)
    caminho_pdf = os.path.join(pasta_docs, nome_arq)

    c = rl_canvas.Canvas(caminho_pdf, pagesize=A4)
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

    # ── Cabeçalho — logo oficial + textos ────────

    # Fundo branco
    c.setFillColor(colors.white)
    c.rect(0, h - 3.4*cm, w, 3.4*cm, fill=1, stroke=0)

    # Linha inferior do cabeçalho
    c.setStrokeColor(colors.HexColor("#CCCCCC"))
    c.line(1.5*cm, h - 3.3*cm, w - 1.5*cm, h - 3.3*cm)

    # Logo SP embutido
    try:
        img_bytes  = _b64.b64decode(LOGO_SP_B64)
        pil_img    = Image.open(io.BytesIO(img_bytes))
        logo_h     = 2.2*cm
        logo_w     = logo_h * (pil_img.width / pil_img.height)
        img_reader = ImageReader(io.BytesIO(img_bytes))
        c.drawImage(img_reader, 1.5*cm, h - 3.1*cm, width=logo_w, height=logo_h, mask="auto")
        txt_x = 1.5*cm + logo_w + 0.4*cm
    except Exception:
        txt_x = 1.5*cm

    # Textos do cabeçalho
    txt("SECRETARIA DE ESTADO DA EDUCAÇÃO",
        txt_x, h - 1.1*cm, tamanho=10, bold=True)
    txt("UNIDADE REGIONAL DE ENSINO DE MAUÁ",
        txt_x, h - 1.65*cm, tamanho=9)
    txt("ESCOLA ESTADUAL E.E. JOÃO PAULO II",
        txt_x, h - 2.15*cm, tamanho=9)
    txt("Rua Barnabé Costa, 57 – Campo Verde – Mauá – SP – CEP 09320-015",
        txt_x, h - 2.65*cm, tamanho=7.5, cor=colors.HexColor("#555555"))
    txt("Fone: (11) 4514-7259  –  E-mail: e038453a@educacao.sp.gov.br",
        txt_x, h - 3.1*cm, tamanho=7.5, cor=colors.HexColor("#555555"))

    # ── Título da ficha ─────────────────────────
    cy = h - 4.2*cm
    c.setStrokeColor(colors.HexColor("#1A1A1A"))
    c.setFillColor(colors.white)
    c.rect(1.5*cm, cy - 0.5*cm, w - 3*cm, 0.85*cm, fill=1, stroke=1)
    txt("FICHA DE OCORRÊNCIA DISCIPLINAR", w/2, cy - 0.2*cm, tamanho=12, bold=True,
        cor=colors.HexColor("#1A1A1A"), align="center")

    # ── Identificação ───────────────────────────
    cy -= 1.3*cm
    txt("IDENTIFICAÇÃO", 1.5*cm, cy, tamanho=9, bold=True, cor=colors.HexColor("#0A2C5E"))
    linha_h(cy - 0.15*cm, cor=colors.HexColor("#0A2C5E"))

    # Layout VERTICAL PERFEITO (valores colados nos labels)
    cy -= 0.7*cm
    txt("Nome do Aluno: ", 1.5*cm, cy, tamanho=9, bold=True)
    txt(dados["aluno"], 4.1*cm, cy, tamanho=9)  # ← 3.2cm
    cy -= 0.52*cm  # ← menos espaço entre linhas

    txt("Série: ", 1.5*cm, cy, tamanho=9, bold=True)
    txt(dados["serie"], 2.5*cm, cy, tamanho=9)  # ← 2.8cm (série é curta)
    cy -= 0.52*cm

    txt("Data: ", 1.5*cm, cy, tamanho=9, bold=True)
    txt(dados["data"], 2.4*cm, cy, tamanho=9)   # ← 2.6cm (data curta)
    cy -= 0.52*cm

    txt("Relatado por: ", 1.5*cm, cy, tamanho=9, bold=True)
    txt(dados["relatado_por"], 3.7*cm, cy, tamanho=9)  # ← 3.4cm


    # ── Ocorrências ─────────────────────────────
    cy -= 1.0*cm
    txt("OCORRÊNCIA", 1.5*cm, cy, tamanho=9, bold=True, cor=colors.HexColor("#0A2C5E"))
    linha_h(cy - 0.15*cm, cor=colors.HexColor("#0A2C5E"))

    cy -= 0.5*cm
    box   = 0.28*cm   # tamanho do quadrado
    # No ReportLab, drawString usa a baseline do texto.
    # Fonte 9pt ≈ 0.317cm de altura; descida ≈ 0.07cm abaixo da baseline.
    def draw_checkbox(cx_left, cy_line, marcado):
        bx = cx_left
        by = cy_line - 0.06*cm          # base do box levemente abaixo da baseline
        c.setStrokeColor(colors.HexColor("#0A2C5E"))
        c.setFillColor(colors.HexColor("#0A2C5E") if marcado else colors.white)
        c.rect(bx, by, box, box, fill=1, stroke=1)
        if marcado:
            c.setFillColor(colors.white)
            c.setFont("Helvetica-Bold", 7)
            c.drawString(bx + 0.03*cm, by + 0.05*cm, "X")

    for chave, rotulo in OCORRENCIAS:
        draw_checkbox(1.5*cm, cy, dados.get(chave, False))
        txt(rotulo, 1.5*cm + box + 0.15*cm, cy, tamanho=9)
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

    if len(linhas) > 8:
        messagebox.showwarning(
            "Relato muito longo",
            f"O relato possui {len(linhas)} linhas, mas o PDF comporta no máximo 8.\n\n"
            f"As linhas excedentes serão cortadas. Considere resumir o texto."
        )

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

    cy -= 0.5*cm
    for chave, rotulo in PROVIDENCIAS:
        draw_checkbox(1.5*cm, cy, dados.get(chave, False))
        txt(rotulo, 1.5*cm + box + 0.15*cm, cy, tamanho=9)
        cy -= 0.52*cm

    # ── Campos finais ───────────────────────────
    cy -= 0.6*cm
    linha_h(cy + 0.3*cm, cor=colors.HexColor("#0A2C5E"))

    txt("Registro no Livro de Ata de Ocorrências — Página Nº: ", 1.5*cm, cy, tamanho=9, bold=True)
    txt(dados.get("pag_ata", ""), 9.7
    *cm, cy, tamanho=9)
    cy -= 0.6*cm
    txt("Ocorrência Atendida por: ", 1.5*cm, cy, tamanho=9, bold=True)
    txt(dados.get("atendida_por", ""), 5.4*cm, cy, tamanho=9)
    cy -= 0.6*cm
    txt("Ciência do Responsável: ", 1.5*cm, cy, tamanho=9, bold=True)
    txt(dados.get("ciencia_resp", ""), 5.4*cm, cy, tamanho=9)

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
    return caminho_pdf


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
            f"{aluno}, registrada em {data}.\n\n"
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
#   ENVIO POR WHATSAPP
# ══════════════════════════════════════════════
def enviar_whatsapp(numero: str, caminho_pdf: str, aluno: str) -> bool:
    try:
        numero_limpo = numero.strip().replace(" ", "").replace("-", "").replace("(", "").replace(")", "")
        if not numero_limpo.startswith("+"):
            numero_limpo = "+55" + numero_limpo
        mensagem = f"Venho por meio desta mensagem, notificar que o aluno {aluno} recebeu uma ocorrência na sala de aula; verifique seu e-mail para ver a ocorrência ou aguarde o evnio do PDF."
        pywhatkit.sendwhatmsg_instantly(numero_limpo, mensagem, wait_time=15, tab_close=False)
        return True
    except Exception as e:
        messagebox.showwarning(
            "WhatsApp não enviado",
            f"Não foi possível enviar a mensagem pelo WhatsApp.\n\n"
            f"Motivo: {e}\n\n"
            f"Verifique se o WhatsApp Web está logado no Chrome e tente novamente."
        )
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
            scroll_units = int(-1 * (event.delta / 120)) * 35
            self.scroll._parent_canvas.yview_scroll(scroll_units, "units")
        except Exception:
            pass

    # ── Helpers de layout ──────────────────────
    def _secao(self, pai, titulo: str) -> ctk.CTkFrame:
        frame = ctk.CTkFrame(pai, corner_radius=10)
        frame.pack(fill="x", padx=18, pady=(0, 10))
        ctk.CTkLabel(frame, text=titulo, font=ctk.CTkFont(size=12, weight="bold"),
                     text_color="#0A2C5E").pack(anchor="w", padx=14, pady=(10, 4))
        return frame

    def _campo(self, pai, rotulo: str, largura: int = 300, valor_padrao: str = "") -> ctk.CTkEntry:
        linha = ctk.CTkFrame(pai, fg_color="transparent")
        linha.pack(fill="x", padx=14, pady=3)
        ctk.CTkLabel(linha, text=rotulo, width=160, anchor="w").pack(side="left")
        entry = ctk.CTkEntry(linha, width=largura)
        entry.insert(0, valor_padrao)
        entry.pack(side="left")
        return entry

    # ── Construção da UI ───────────────────────
    def _build_ui(self):
        # Scroll externo
        self.scroll = ctk.CTkScrollableFrame(self, corner_radius=0)
        self.scroll.pack(fill="both", expand=True, padx=0, pady=0)

        # ── Cabeçalho — fiel ao papel oficial ──────

        cab = ctk.CTkFrame(self.scroll, fg_color="white", corner_radius=0)
        cab.pack(fill="x", padx=0, pady=(0, 14))

        topo = ctk.CTkFrame(cab, fg_color="white", corner_radius=0)
        topo.pack(fill="x", padx=18, pady=(14, 4))

        # Logo SP — imagem oficial embutida
        try:
            img_data = _b64.b64decode(LOGO_SP_B64)
            pil_img  = Image.open(io.BytesIO(img_data))
            self._logo_img = ImageTk.PhotoImage(pil_img)
            tk.Label(topo, image=self._logo_img, bg="white",
                     borderwidth=0).pack(side="left", padx=(0, 14))
        except Exception:
            pass  # se falhar, segue sem logo

        textos = ctk.CTkFrame(topo, fg_color="white", corner_radius=0)
        textos.pack(side="left", fill="x", expand=True)
        ctk.CTkLabel(textos, text="SECRETARIA DE ESTADO DA EDUCAÇÃO",
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color="#1A1A1A", anchor="w").pack(anchor="w")
        ctk.CTkLabel(textos, text="UNIDADE REGIONAL DE ENSINO DE MAUÁ",
                     font=ctk.CTkFont(size=10, weight="bold"),
                     text_color="#1A1A1A", anchor="w").pack(anchor="w")
        ctk.CTkLabel(textos, text="ESCOLA ESTADUAL E.E. JOÃO PAULO II",
                     font=ctk.CTkFont(size=10),
                     text_color="#333333", anchor="w").pack(anchor="w")
        ctk.CTkLabel(textos,
                     text="Rua Barnabé Costa, 57 – Campo Verde – Mauá – SP – CEP 09320-015",
                     font=ctk.CTkFont(size=8), text_color="#555555", anchor="w").pack(anchor="w")
        ctk.CTkLabel(textos,
                     text="Fone: (11) 4514-7259  –  E-mail: e038453a@educacao.sp.gov.br",
                     font=ctk.CTkFont(size=8), text_color="#555555", anchor="w").pack(anchor="w")

        sep = tk.Frame(cab, bg="#CCCCCC", height=1)
        sep.pack(fill="x", padx=18, pady=(6, 0))

        ctk.CTkLabel(cab, text="FICHA DE OCORRÊNCIA DISCIPLINAR",
                     font=ctk.CTkFont(size=13, weight="bold"),
                     text_color="#1A1A1A").pack(pady=(8, 14))

        # ── 1. Identificação ─────────────────────
        f_id = self._secao(self.scroll, " [ 📁 ]  Registro  ")
        self.entry_aluno       = self._campo(f_id, "Nome do Aluno:", 300)
        self.entry_serie       = self._campo(f_id, "Série / Turma:", 100)
        self.entry_data        = self._campo(f_id, "Data:", 120,
                                             datetime.now().strftime("%d/%m/%Y"))
        self.entry_relatado    = self._campo(f_id, "Relatado por:", 260)

        # ── 2. Ocorrências ───────────────────────
        f_oc = self._secao(self.scroll, " [ 📝 ]  Motivo da Ocorrência  ")
        self.vars_oc = {}
        _fonte_check = ctk.CTkFont(size=12)   # fonte criada UMA vez, reaproveitada em todos os checkboxes
        for chave, texto in OCORRENCIAS:
            v = ctk.BooleanVar()
            self.vars_oc[chave] = v
            ctk.CTkCheckBox(f_oc, text=texto, variable=v, font=_fonte_check).pack(anchor="w", padx=22, pady=2)

        # campo "Outra" descrição
        linha_outra = ctk.CTkFrame(f_oc, fg_color="transparent")
        linha_outra.pack(fill="x", padx=30, pady=(0, 8))
        ctk.CTkLabel(linha_outra, text="  Descrever 'Outro':", width=160, anchor="w").pack(side="left")
        self.entry_outra = ctk.CTkEntry(linha_outra, width=350)
        self.entry_outra.pack(side="left")

        # ── 3. Relato ────────────────────────────
        f_rel = self._secao(self.scroll, " [ 🗂 ]  Relatório da Ocorrência  ")
        self.text_relato = ctk.CTkTextbox(f_rel, height=110, corner_radius=6)
        self.text_relato.pack(fill="x", padx=14, pady=(0, 10))

        # ── 4. Providências ──────────────────────
        f_pv = self._secao(self.scroll, " [ 📠 ]  Providência tomada ( Equipe Gestora )  ")
        self.vars_pv = {}
        for chave, texto in PROVIDENCIAS:
            v = ctk.BooleanVar()
            self.vars_pv[chave] = v
            ctk.CTkCheckBox(f_pv, text=texto, variable=v, font=_fonte_check).pack(anchor="w", padx=22, pady=2)

        # ── 5. Campos finais ─────────────────────
        f_fin = self._secao(self.scroll, " [ 📂 ]  Registro Final ( Equipe Gestora )  ")
        self.entry_pag_ata     = self._campo(f_fin, "Nº da Pág. do Ata:", 44)
        self.entry_atendida    = self._campo(f_fin, "Atendido por:", 170)
        self.entry_ciencia     = self._campo(f_fin, "Ciência do Responsável:", 170)
        self.entry_whatsapp    = self._campo(f_fin, "Whatsapp Escolar:", 96, WHATSAPP_ESCOLAR)
        self.entry_whatsapp.configure(state="readonly")

        # ── Botão ────────────────────────────────
        ctk.CTkButton(
            self.scroll,
            text="CLIQUE PARA GERAR PDF ( 🗃 )",
            font=ctk.CTkFont(size=13, weight="bold"),
            height=48,
            corner_radius=10,
            fg_color="#28364A",
            hover_color="#323C61",
            command=self._confirmar_e_enviar
        ).pack(padx=18, pady=16)

    # ── Ação do botão ──────────────────────────
    def _confirmar_e_enviar(self):
        aluno = self.entry_aluno.get().strip()
        serie = self.entry_serie.get().strip()
        data = self.entry_data.get().strip()
        relatado = self.entry_relatado.get().strip()

        campos_vazios = []
        if not aluno:
            campos_vazios.append("Nome do Aluno")
        if not serie:
            campos_vazios.append("Série / Turma")
        if not data:
            campos_vazios.append("Data")
        if not relatado:
            campos_vazios.append("Relatado por")

        if campos_vazios:
            messagebox.showwarning(
                "Campos obrigatórios",
                "Preencha os seguintes campos antes de continuar:\n\n• " +
                "\n• ".join(campos_vazios)
            )
            return

        resposta = messagebox.askyesno(
            "Confirmar",
            f"Deseja gerar e enviar a ocorrência de\n\n"
            f"Aluno: {aluno}\n"
            f"Data:  {data}\n\n"
            f"O PDF será enviado para:\n{EMAIL_DESTINO}"
        )
        if not resposta:
            return

        dados = {
            "aluno":        aluno,
            "serie":        serie,
            "data":         data,
            "relatado_por": relatado,
            "relato":       self.text_relato.get("1.0", "end").strip(),
            "outra_desc":   self.entry_outra.get().strip(),
            "pag_ata":      self.entry_pag_ata.get().strip(),
            "atendida_por": self.entry_atendida.get().strip(),
            "ciencia_resp": self.entry_ciencia.get().strip(),
            "whatsapp":     self.entry_whatsapp.get().strip(),
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
            # 1. Envia o whatsapp primeiro, (Não mexer na tela durante o envio)
            numero_wp = dados.get("whatsapp", "")
            if numero_wp:
                # O sistema vai focar no Chrome agora
                enviar_whatsapp(numero_wp, pdf_path, dados["aluno"])
            
            # 2. SÓ DEPOIS de tentar ou enviar o Zap, mostra o aviso na tela
            messagebox.showinfo(
                "Sucesso! ✅",
                f"PDF gerado e enviado com sucesso!\n\nArquivo: {pdf_path}\nEnviado para: {EMAIL_DESTINO}"
            )
            
            # 3. POR ÚLTIMO, abre a pasta do Windows
            # Isso evita que a pasta do Windows não permita que o "pywhatkit" finalize o seu processo primeiro
            os.startfile(os.path.join(os.path.expanduser("~"), "One Drive", "Documents", "Ocorrencias_JPII")) 
        else:
            messagebox.showwarning(
                "PDF gerado, mas e-mail falhou",
                f"O PDF foi salvo em:\n{pdf_path}"
            )


# ══════════════════════════════════════════════
if __name__ == "__main__":
    app = App()
    app.mainloop()
    # teste