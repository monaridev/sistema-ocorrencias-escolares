"""
=============================================================
  FICHA DE OCORRÊNCIA DISCIPLINAR
  E.E. João Paulo II — Mauá/SP
=============================================================
  Dependências:
    pip install customtkinter reportlab pywhatkit dotenv

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
from reportlab.pdfbase.pdfmetrics import stringWidth

# ─────────────────────────────────────────────
#   CONFIGURAÇÕES DE EMAIL 
# ─────────────────────────────────────────────

#   1. EMAIL_REMETENTE = E-Mail Que está enviando

#   2. SENHA_APP = Senha Gerada pelo Google --> "Gerenciar minha conta do Google" --> "Senhas de App"

#   3. EMAIL_DESTINO = E-Mail Que receberá 

load_dotenv()
EMAIL_REMETENTE = os.getenv("EMAIL_REMETENTE")
SENHA_APP = os.getenv("SENHA_APP")
EMAIL_DESTINO = os.getenv("EMAIL_DESTINO")

# ─────────────────────────────────────────────
#   CONFIGURAÇÃO DO NÚMERO DO WHATSAPP 
# ─────────────────────────────────────────────

#   1.Whatsapp Que receberá as mensagens ( PyWhatKit Lib )

WHATSAPP_ESCOLAR = os.getenv("WHATSAPP_ESCOLAR")

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

# ── Paleta de cores ──────
COR_PRIMARIA    = "#0A2C5E"   # azul SP escuro
COR_ACENTO      = "#C8102E"   # vermelho SP
COR_FUNDO       = "#F0F2F5"   # cinza claro de fundo
COR_CARD        = "#FFFFFF"   # branco dos cards
COR_BORDA       = "#D8DCE6"   # borda suave
COR_TEXTO       = "#1A1F2E"   # texto principal
COR_SUBTEXTO    = "#5A6478"   # texto secundário
COR_HOVER       = "#1A4A8A"   # hover dos botões
COR_CHECK_OK    = "#0A7C3A"   # verde ao marcar


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
    if dados.get("oc11", False) and dados.get("outra_desc", "").strip():
        txt(f"   → {dados['outra_desc']}", 2.1*cm, cy, tamanho=8.5, cor=colors.HexColor("#333333"))
        cy -= 0.52*cm

    # ── Relato ──────────────────────────────────
    cy -= 0.4*cm
    txt("RELATO DA OCORRÊNCIA", 1.5*cm, cy, tamanho=9, bold=True, cor=colors.HexColor("#0A2C5E"))
    linha_h(cy - 0.15*cm, cor=colors.HexColor("#0A2C5E"))

    cy -= 0.5*cm
    relato = dados.get("relato", "").strip()
    largura_util_pts = w - 3*cm

    palavras = relato.split()
    linhas, linha_atual = [], ""
    for p in palavras:
        teste = (linha_atual + " " + p).strip()
        if stringWidth(teste, "Helvetica", 9) <= largura_util_pts:
            linha_atual = teste
        else:
            linhas.append(linha_atual)
            linha_atual = p
    if linha_atual:
        linhas.append(linha_atual)

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
        mensagem = f"Venho por meio desta mensagem, notificar que o aluno {aluno} recebeu uma ocorrência na sala de aula; verifique seu e-mail para ver a ocorrência ou aguarde o envio do PDF."
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
#   INTERFACE GRÁFICA 
# ══════════════════════════════════════════════
class App(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Ficha de Ocorrência Disciplinar — E.E. João Paulo II")
        self.geometry("820x920")
        self.minsize(700, 600)
        self.resizable(True, True)
        self.configure(fg_color=COR_FUNDO)
        self._build_ui()
        self.bind_all("<MouseWheel>", self._scroll_mouse)

    def _scroll_mouse(self, event):
        try:
            scroll_units = int(-1 * (event.delta / 120)) * 35
            self.scroll._parent_canvas.yview_scroll(scroll_units, "units")
        except Exception:
            pass

    # ── Helpers de layout ──────────────────────
    def _card(self, pai, titulo: str, icone: str = "") -> ctk.CTkFrame:
        """Cria um card moderno com título e linha divisória colorida."""
        wrapper = ctk.CTkFrame(pai, corner_radius=14, fg_color=COR_CARD,
                               border_width=1, border_color=COR_BORDA)
        wrapper.pack(fill="x", padx=20, pady=(0, 14))

        # Faixa superior colorida
        topo = ctk.CTkFrame(wrapper, fg_color=COR_PRIMARIA, corner_radius=0, height=4)
        topo.pack(fill="x")
        # Correção para os cantos superiores
        topo_inner = tk.Frame(wrapper, bg=COR_PRIMARIA, height=8)
        topo_inner.pack(fill="x")

        cab = ctk.CTkFrame(wrapper, fg_color="transparent")
        cab.pack(fill="x", padx=18, pady=(10, 6))

        if icone:
            ctk.CTkLabel(cab, text=icone, font=ctk.CTkFont(size=18),
                         text_color=COR_PRIMARIA, width=30).pack(side="left", padx=(0, 8))

        ctk.CTkLabel(cab, text=titulo,
                     font=ctk.CTkFont(size=13, weight="bold"),
                     text_color=COR_PRIMARIA).pack(side="left")

        # Linha divisória sutil
        tk.Frame(wrapper, bg=COR_BORDA, height=1).pack(fill="x", padx=18, pady=(0, 12))

        return wrapper

    def _campo(self, pai, rotulo: str, largura: int = 300, valor_padrao: str = "",
               placeholder: str = "") -> ctk.CTkEntry:
        """Campo de entrada com rótulo elegante acima."""
        bloco = ctk.CTkFrame(pai, fg_color="transparent")
        bloco.pack(fill="x", padx=18, pady=(0, 10))

        ctk.CTkLabel(bloco, text=rotulo,
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color=COR_SUBTEXTO, anchor="w").pack(anchor="w", pady=(0, 3))

        entry = ctk.CTkEntry(bloco,
                             width=largura,
                             height=36,
                             corner_radius=8,
                             border_width=1,
                             border_color=COR_BORDA,
                             fg_color="#F8F9FC",
                             text_color=COR_TEXTO,
                             placeholder_text=placeholder,
                             font=ctk.CTkFont(size=12))
        entry.insert(0, valor_padrao)
        entry.pack(anchor="w")

        # Efeito de foco: muda borda ao entrar/sair
        entry.bind("<FocusIn>",  lambda e: entry.configure(border_color=COR_PRIMARIA, fg_color="white"))
        entry.bind("<FocusOut>", lambda e: entry.configure(border_color=COR_BORDA,   fg_color="#F8F9FC"))

        return entry

    def _campo_linha(self, pai, rotulo: str, largura: int = 220, valor_padrao: str = "",
                     placeholder: str = "") -> ctk.CTkEntry:
        """Campo compacto lado a lado (para grids de 2 colunas)."""
        bloco = ctk.CTkFrame(pai, fg_color="transparent")
        bloco.pack(side="left", fill="x", expand=True, padx=(0, 12))

        ctk.CTkLabel(bloco, text=rotulo,
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color=COR_SUBTEXTO, anchor="w").pack(anchor="w", pady=(0, 3))

        entry = ctk.CTkEntry(bloco,
                             height=36,
                             corner_radius=8,
                             border_width=1,
                             border_color=COR_BORDA,
                             fg_color="#F8F9FC",
                             text_color=COR_TEXTO,
                             placeholder_text=placeholder,
                             font=ctk.CTkFont(size=12))
        entry.insert(0, valor_padrao)
        entry.pack(fill="x")

        entry.bind("<FocusIn>",  lambda e: entry.configure(border_color=COR_PRIMARIA, fg_color="white"))
        entry.bind("<FocusOut>", lambda e: entry.configure(border_color=COR_BORDA,   fg_color="#F8F9FC"))

        return entry

    def _checkbox_moderno(self, pai, texto: str, var: tk.BooleanVar):
        """Checkbox com visual moderno e feedback de cor."""
        linha = ctk.CTkFrame(pai, fg_color="transparent", corner_radius=8)
        linha.pack(fill="x", padx=18, pady=2)

        cb = ctk.CTkCheckBox(
            linha,
            text=texto,
            variable=var,
            font=ctk.CTkFont(size=12),
            text_color=COR_TEXTO,
            fg_color=COR_CHECK_OK,
            hover_color=COR_PRIMARIA,
            border_color=COR_BORDA,
            border_width=2,
            checkmark_color="white",
            corner_radius=5,
        )
        cb.pack(anchor="w", padx=6, pady=2)

        # Destaca fundo da linha ao marcar
        def _atualizar(*_):
            if var.get():
                linha.configure(fg_color="#EEF6F1")
                cb.configure(text_color=COR_CHECK_OK)
            else:
                linha.configure(fg_color="transparent")
                cb.configure(text_color=COR_TEXTO)

        var.trace_add("write", _atualizar)
        return cb

    # ── Construção da UI ───────────────────────
    def _build_ui(self):
        # ── Topo fixo com identidade visual ─────────────────
        header = tk.Frame(self, bg=COR_PRIMARIA, height=72)
        header.pack(fill="x", side="top")
        header.pack_propagate(False)

        inner_h = tk.Frame(header, bg=COR_PRIMARIA)
        inner_h.pack(fill="both", expand=True, padx=24, pady=0)

        # Logo SP no header
        try:
            img_data    = _b64.b64decode(LOGO_SP_B64)
            pil_img     = Image.open(io.BytesIO(img_data))
            # Redimensiona para caber no header
            h_logo = 46
            w_logo = int(h_logo * pil_img.width / pil_img.height)
            pil_img_r   = pil_img.resize((w_logo, h_logo), Image.LANCZOS)
            self._logo_img = ImageTk.PhotoImage(pil_img_r)
            tk.Label(inner_h, image=self._logo_img, bg=COR_PRIMARIA,
                     borderwidth=0).pack(side="left", pady=13)
        except Exception:
            pass

        # Texto do header
        txt_h = tk.Frame(inner_h, bg=COR_PRIMARIA)
        txt_h.pack(side="left", padx=14, pady=10)

        tk.Label(txt_h, text="E.E. JOÃO PAULO II",
                 font=("Segoe UI", 15, "bold"),
                 bg=COR_PRIMARIA, fg="white").pack(anchor="w")
        tk.Label(txt_h, text="Ficha de Ocorrência Disciplinar  ·  Mauá – SP",
                 font=("Segoe UI", 9),
                 bg=COR_PRIMARIA, fg="#A8C4E8").pack(anchor="w")

        # Pill de status no canto direito
        self._status_var = tk.StringVar(value="● Pronto para preencher")
        self._status_lbl = tk.Label(inner_h,
                                    textvariable=self._status_var,
                                    font=("Segoe UI", 9),
                                    bg=COR_PRIMARIA, fg="#6DBFFF")
        self._status_lbl.pack(side="right", pady=10)

        # ── Faixa vermelha decorativa ─────────────────────────
        tk.Frame(self, bg=COR_ACENTO, height=3).pack(fill="x")

        # ── Área rolável ─────────────────────────────────────
        self.scroll = ctk.CTkScrollableFrame(self, corner_radius=0,
                                             fg_color=COR_FUNDO,
                                             scrollbar_button_color=COR_BORDA,
                                             scrollbar_button_hover_color=COR_PRIMARIA)
        self.scroll.pack(fill="both", expand=True, padx=0, pady=0)

        # Espaço superior
        tk.Frame(self.scroll, bg=COR_FUNDO, height=16).pack(fill="x")

        # ══ 1. CARD — Identificação ══════════════════════════
        c_id = self._card(self.scroll, "Registro do Aluno", "📋")

        # Grid de 2 colunas para nome + série
        row1 = ctk.CTkFrame(c_id, fg_color="transparent")
        row1.pack(fill="x", padx=18, pady=(0, 0))

        frame_nome = ctk.CTkFrame(row1, fg_color="transparent")
        frame_nome.pack(side="left", fill="x", expand=True, padx=(0, 12))
        ctk.CTkLabel(frame_nome, text="Nome do Aluno",
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color=COR_SUBTEXTO, anchor="w").pack(anchor="w", pady=(0, 3))
        self.entry_aluno = ctk.CTkEntry(frame_nome, height=36, corner_radius=8,
                                        border_width=1, border_color=COR_BORDA,
                                        fg_color="#F8F9FC", text_color=COR_TEXTO,
                                        placeholder_text="Nome completo do aluno",
                                        font=ctk.CTkFont(size=12))
        self.entry_aluno.pack(fill="x")
        self.entry_aluno.bind("<FocusIn>",  lambda e: self.entry_aluno.configure(border_color=COR_PRIMARIA, fg_color="white"))
        self.entry_aluno.bind("<FocusOut>", lambda e: self.entry_aluno.configure(border_color=COR_BORDA, fg_color="#F8F9FC"))

        frame_serie = ctk.CTkFrame(row1, fg_color="transparent")
        frame_serie.pack(side="left", padx=(0, 0))
        ctk.CTkLabel(frame_serie, text="Série / Turma",
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color=COR_SUBTEXTO, anchor="w").pack(anchor="w", pady=(0, 3))
        self.entry_serie = ctk.CTkEntry(frame_serie, width=110, height=36, corner_radius=8,
                                         border_width=1, border_color=COR_BORDA,
                                         fg_color="#F8F9FC", text_color=COR_TEXTO,
                                         placeholder_text="Ex: 3ºA",
                                         font=ctk.CTkFont(size=12))
        self.entry_serie.pack(anchor="w")
        self.entry_serie.bind("<FocusIn>",  lambda e: self.entry_serie.configure(border_color=COR_PRIMARIA, fg_color="white"))
        self.entry_serie.bind("<FocusOut>", lambda e: self.entry_serie.configure(border_color=COR_BORDA, fg_color="#F8F9FC"))

        # Grid de 2 colunas para data + relatado
        row2 = ctk.CTkFrame(c_id, fg_color="transparent")
        row2.pack(fill="x", padx=18, pady=(10, 14))

        frame_data = ctk.CTkFrame(row2, fg_color="transparent")
        frame_data.pack(side="left", padx=(0, 12))
        ctk.CTkLabel(frame_data, text="Data",
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color=COR_SUBTEXTO, anchor="w").pack(anchor="w", pady=(0, 3))
        self.entry_data = ctk.CTkEntry(frame_data, width=130, height=36, corner_radius=8,
                                        border_width=1, border_color=COR_BORDA,
                                        fg_color="#F8F9FC", text_color=COR_TEXTO,
                                        font=ctk.CTkFont(size=12))
        self.entry_data.insert(0, datetime.now().strftime("%d/%m/%Y"))
        self.entry_data.pack(anchor="w")
        self.entry_data.bind("<FocusIn>",  lambda e: self.entry_data.configure(border_color=COR_PRIMARIA, fg_color="white"))
        self.entry_data.bind("<FocusOut>", lambda e: self.entry_data.configure(border_color=COR_BORDA, fg_color="#F8F9FC"))

        frame_rel = ctk.CTkFrame(row2, fg_color="transparent")
        frame_rel.pack(side="left", fill="x", expand=True)
        ctk.CTkLabel(frame_rel, text="Relatado por",
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color=COR_SUBTEXTO, anchor="w").pack(anchor="w", pady=(0, 3))
        self.entry_relatado = ctk.CTkEntry(frame_rel, height=36, corner_radius=8,
                                            border_width=1, border_color=COR_BORDA,
                                            fg_color="#F8F9FC", text_color=COR_TEXTO,
                                            placeholder_text="Nome do professor(a)",
                                            font=ctk.CTkFont(size=12))
        self.entry_relatado.pack(fill="x")
        self.entry_relatado.bind("<FocusIn>",  lambda e: self.entry_relatado.configure(border_color=COR_PRIMARIA, fg_color="white"))
        self.entry_relatado.bind("<FocusOut>", lambda e: self.entry_relatado.configure(border_color=COR_BORDA, fg_color="#F8F9FC"))

        # ══ 2. CARD — Motivo da Ocorrência ══════════════════
        c_oc = self._card(self.scroll, "Motivo da Ocorrência", "⚠️")

        self.vars_oc = {}
        for chave, texto in OCORRENCIAS:
            v = ctk.BooleanVar()
            self.vars_oc[chave] = v
            self._checkbox_moderno(c_oc, texto, v)

        # Campo "Outra descrição"
        sep_outra = ctk.CTkFrame(c_oc, fg_color=COR_BORDA, height=1)
        sep_outra.pack(fill="x", padx=18, pady=(8, 10))

        bloco_outra = ctk.CTkFrame(c_oc, fg_color="transparent")
        bloco_outra.pack(fill="x", padx=18, pady=(0, 14))
        ctk.CTkLabel(bloco_outra, text="Descrição para 'Outro'",
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color=COR_SUBTEXTO, anchor="w").pack(anchor="w", pady=(0, 3))
        self.entry_outra = ctk.CTkEntry(bloco_outra, height=36, corner_radius=8,
                                         border_width=1, border_color=COR_BORDA,
                                         fg_color="#F8F9FC", text_color=COR_TEXTO,
                                         placeholder_text="Descreva o motivo 'Outro' aqui...",
                                         font=ctk.CTkFont(size=12))
        self.entry_outra.pack(fill="x")
        self.entry_outra.bind("<FocusIn>",  lambda e: self.entry_outra.configure(border_color=COR_PRIMARIA, fg_color="white"))
        self.entry_outra.bind("<FocusOut>", lambda e: self.entry_outra.configure(border_color=COR_BORDA, fg_color="#F8F9FC"))

        # ══ 3. CARD — Relato ═════════════════════════════════
        c_rel = self._card(self.scroll, "Relatório da Ocorrência", "📝")

        ctk.CTkLabel(c_rel, text="Descreva detalhadamente o ocorrido",
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color=COR_SUBTEXTO, anchor="w").pack(anchor="w", padx=18, pady=(0, 4))

        self.text_relato = ctk.CTkTextbox(c_rel,
                                           height=120,
                                           corner_radius=8,
                                           border_width=1,
                                           border_color=COR_BORDA,
                                           fg_color="#F8F9FC",
                                           text_color=COR_TEXTO,
                                           font=ctk.CTkFont(size=12),
                                           wrap="word")
        self.text_relato.pack(fill="x", padx=18, pady=(0, 6))

        # Rodapé do relato: aviso + contador de caracteres lado a lado
        rodape_rel = ctk.CTkFrame(c_rel, fg_color="transparent")
        rodape_rel.pack(fill="x", padx=18, pady=(0, 14))

        ctk.CTkLabel(rodape_rel,
                     text="⚠  Máximo de 400 caracteres no PDF.",
                     font=ctk.CTkFont(size=10),
                     text_color="#E07B00",
                     anchor="w").pack(side="left")

        self._contador_var = tk.StringVar(value="0 / 400")
        self._contador_lbl = ctk.CTkLabel(rodape_rel,
                                           textvariable=self._contador_var,
                                           font=ctk.CTkFont(size=10, weight="bold"),
                                           text_color=COR_SUBTEXTO,
                                           anchor="e")
        self._contador_lbl.pack(side="right")

        # Atualiza o contador a cada tecla digitada no textbox
        self.text_relato._textbox.bind("<KeyRelease>", self._atualizar_contador)
        self.text_relato._textbox.bind("<<Paste>>",    self._atualizar_contador)

        # ══ 4. CARD — Providências ════════════════════════════
        c_pv = self._card(self.scroll, "Providência Tomada — Equipe Gestora", "📋")

        self.vars_pv = {}
        for chave, texto in PROVIDENCIAS:
            v = ctk.BooleanVar()
            self.vars_pv[chave] = v
            self._checkbox_moderno(c_pv, texto, v)

        tk.Frame(c_pv, bg=COR_FUNDO, height=8).pack()

        # ══ 5. CARD — Registro Final ══════════════════════════
        c_fin = self._card(self.scroll, "Registro Final — Equipe Gestora", "🗂️")

        row_fin1 = ctk.CTkFrame(c_fin, fg_color="transparent")
        row_fin1.pack(fill="x", padx=18, pady=(0, 10))

        # Pág. do Ata
        bloco_pag = ctk.CTkFrame(row_fin1, fg_color="transparent")
        bloco_pag.pack(side="left", padx=(0, 12))
        ctk.CTkLabel(bloco_pag, text="Nº da Pág. do Ata",
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color=COR_SUBTEXTO, anchor="w").pack(anchor="w", pady=(0, 3))
        self.entry_pag_ata = ctk.CTkEntry(bloco_pag, width=80, height=36, corner_radius=8,
                                           border_width=1, border_color=COR_BORDA,
                                           fg_color="#F8F9FC", text_color=COR_TEXTO,
                                           font=ctk.CTkFont(size=12))
        self.entry_pag_ata.pack(anchor="w")
        self.entry_pag_ata.bind("<FocusIn>",  lambda e: self.entry_pag_ata.configure(border_color=COR_PRIMARIA, fg_color="white"))
        self.entry_pag_ata.bind("<FocusOut>", lambda e: self.entry_pag_ata.configure(border_color=COR_BORDA, fg_color="#F8F9FC"))

        # Atendida por
        bloco_atend = ctk.CTkFrame(row_fin1, fg_color="transparent")
        bloco_atend.pack(side="left", fill="x", expand=True)
        ctk.CTkLabel(bloco_atend, text="Ocorrência Atendida por",
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color=COR_SUBTEXTO, anchor="w").pack(anchor="w", pady=(0, 3))
        self.entry_atendida = ctk.CTkEntry(bloco_atend, height=36, corner_radius=8,
                                            border_width=1, border_color=COR_BORDA,
                                            fg_color="#F8F9FC", text_color=COR_TEXTO,
                                            placeholder_text="Nome do gestor responsável",
                                            font=ctk.CTkFont(size=12))
        self.entry_atendida.pack(fill="x")
        self.entry_atendida.bind("<FocusIn>",  lambda e: self.entry_atendida.configure(border_color=COR_PRIMARIA, fg_color="white"))
        self.entry_atendida.bind("<FocusOut>", lambda e: self.entry_atendida.configure(border_color=COR_BORDA, fg_color="#F8F9FC"))

        row_fin2 = ctk.CTkFrame(c_fin, fg_color="transparent")
        row_fin2.pack(fill="x", padx=18, pady=(0, 14))

        # Ciência do Responsável
        bloco_cien = ctk.CTkFrame(row_fin2, fg_color="transparent")
        bloco_cien.pack(side="left", fill="x", expand=True, padx=(0, 12))
        ctk.CTkLabel(bloco_cien, text="Ciência do Responsável",
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color=COR_SUBTEXTO, anchor="w").pack(anchor="w", pady=(0, 3))
        self.entry_ciencia = ctk.CTkEntry(bloco_cien, height=36, corner_radius=8,
                                           border_width=1, border_color=COR_BORDA,
                                           fg_color="#F8F9FC", text_color=COR_TEXTO,
                                           placeholder_text="Nome do responsável",
                                           font=ctk.CTkFont(size=12))
        self.entry_ciencia.pack(fill="x")
        self.entry_ciencia.bind("<FocusIn>",  lambda e: self.entry_ciencia.configure(border_color=COR_PRIMARIA, fg_color="white"))
        self.entry_ciencia.bind("<FocusOut>", lambda e: self.entry_ciencia.configure(border_color=COR_BORDA, fg_color="#F8F9FC"))

        # WhatsApp — somente leitura
        bloco_wp = ctk.CTkFrame(row_fin2, fg_color="transparent")
        bloco_wp.pack(side="left")
        ctk.CTkLabel(bloco_wp, text="WhatsApp Escolar",
                     font=ctk.CTkFont(size=11, weight="bold"),
                     text_color=COR_SUBTEXTO, anchor="w").pack(anchor="w", pady=(0, 3))
        self.entry_whatsapp = ctk.CTkEntry(bloco_wp, width=140, height=36, corner_radius=8,
                                            border_width=1, border_color=COR_BORDA,
                                            fg_color="#EDEFF4", text_color=COR_SUBTEXTO,
                                            font=ctk.CTkFont(size=12))
        self.entry_whatsapp.insert(0, WHATSAPP_ESCOLAR)
        self.entry_whatsapp.configure(state="readonly")
        self.entry_whatsapp.pack(anchor="w")

        # ══ BOTÃO DE GERAÇÃO ══════════════════════════════════
        btn_frame = ctk.CTkFrame(self.scroll, fg_color="transparent")
        btn_frame.pack(fill="x", padx=20, pady=(4, 6))

        self.btn_gerar = ctk.CTkButton(
            btn_frame,
            text="🗃   Gerar PDF e Enviar",
            font=ctk.CTkFont(size=14, weight="bold"),
            height=52,
            corner_radius=12,
            fg_color=COR_PRIMARIA,
            hover_color=COR_HOVER,
            text_color="white",
            command=self._confirmar_e_enviar,
        )
        self.btn_gerar.pack(fill="x")

        # Rodapé sutil
        ctk.CTkLabel(self.scroll,
                     text="E.E. João Paulo II  ·  Rua Barnabé Costa, 57 — Campo Verde, Mauá/SP  ·  e038453a@educacao.sp.gov.br",
                     font=ctk.CTkFont(size=9),
                     text_color=COR_SUBTEXTO).pack(pady=(6, 18))

    # ── Contador de caracteres do relato ───────
    def _atualizar_contador(self, event=None):
        texto = self.text_relato.get("1.0", "end-1c")
        total = len(texto)
        self._contador_var.set(f"{total} / 400")
        if total > 400:
            self._contador_lbl.configure(text_color=COR_ACENTO)
        elif total > 320:
            self._contador_lbl.configure(text_color="#E07B00")
        else:
            self._contador_lbl.configure(text_color=COR_SUBTEXTO)

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

        try:
            data_obj = datetime.strptime(data, "%d/%m/%Y")
            if data_obj.year < 2020 or data_obj.year > 2100:
                raise ValueError
        except ValueError:
            messagebox.showwarning(
                "Data inválida",
                f'A data "{data}" não é válida.\n\nUse o formato DD/MM/AAAA.\nExemplo: {datetime.now().strftime("%d/%m/%Y")}'
            )
            self.entry_data.focus()
            return
        
        relato_atual = self.text_relato.get("1.0", "end-1c")
        if len(relato_atual) > 400:
            messagebox.showwarning(
                "Relato muito longo",
                f"O relato possui {len(relato_atual)} caracteres, mas o limite é 400.\n\n"
                f"Reduza o texto antes de continuar."
        )
            self.text_relato.focus()  # já joga o cursor de volta pro campo
            return  # ← bloqueia o envio
        resposta = messagebox.askyesno(
            "Confirmar",
            f"Deseja gerar e enviar a ocorrência de\n\n"
            f"Aluno: {aluno}\n"
            f"Data:  {data}\n\n"
            f"O PDF será enviado para:\n{EMAIL_DESTINO}"
        )
        if not resposta:
            return

        # Feedback visual — processando
        self.btn_gerar.configure(text="⏳  Gerando PDF...", state="disabled", fg_color="#5A7AA8")
        self._status_var.set("● Gerando documento...")
        self.update_idletasks()

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
            self.btn_gerar.configure(text="🗃   Gerar PDF e Enviar", state="normal", fg_color=COR_PRIMARIA)
            self._status_var.set("● Erro ao gerar PDF")
            return

        self._status_var.set("● Enviando e-mail...")
        self.update_idletasks()

        ok = enviar_email(pdf_path, aluno, dados["data"])

        if ok:
            # 1. Envia o whatsapp primeiro, (Não mexer na tela durante o envio)
            numero_wp = dados.get("whatsapp", "")
            if numero_wp:
                self._status_var.set("● Enviando WhatsApp...")
                self.update_idletasks()
                # O sistema vai focar no Chrome agora
                enviar_whatsapp(numero_wp, pdf_path, dados["aluno"])

            # 2. SÓ DEPOIS de tentar ou enviar o Zap, mostra o aviso na tela
            self._status_var.set("✅ Ocorrência enviada com sucesso!")
            self.btn_gerar.configure(text="✅  PDF Gerado e Enviado!", fg_color="#0A7C3A")
            messagebox.showinfo(
                "Sucesso! ✅",
                f"PDF gerado e enviado com sucesso!\n\nArquivo: {pdf_path}\nEnviado para: {EMAIL_DESTINO}"
            )
            # Restaura botão após sucesso
            self.btn_gerar.configure(text="🗃   Gerar PDF e Enviar", state="normal", fg_color=COR_PRIMARIA)
            self._status_var.set("● Pronto para novo registro")

            # 3. POR ÚLTIMO, abre a pasta do Windows
            # Isso evita que a pasta do Windows não permita que o "pywhatkit" finalize o seu processo primeiro
            os.startfile(os.path.join(os.path.expanduser("~"), "Documents", "Ocorrencias_JPII"))
        else:
            self.btn_gerar.configure(text="🗃   Gerar PDF e Enviar", state="normal", fg_color=COR_PRIMARIA)
            self._status_var.set("⚠  PDF salvo, mas e-mail falhou")
            messagebox.showwarning(
                "PDF gerado, mas e-mail falhou",
                f"O PDF foi salvo em:\n{pdf_path}"
            )


# ══════════════════════════════════════════════
if __name__ == "__main__":
    app = App()
    app.mainloop()
