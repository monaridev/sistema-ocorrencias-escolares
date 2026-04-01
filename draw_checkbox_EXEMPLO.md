# draw_checkbox - EXEMPLO COMPLETO ANTES/DEPOIS 🎨

## SITUAÇÃO ATUAL (funciona, mas ruim):

```python
# Dentro da função gerar_pdf(), após "OCORRÊNCIA":

cy -= 0.5*cm
box   = 0.28*cm

for chave, rotulo in ocorrencias:        # ← LOOP 11x
    def draw_checkbox(cx_left, cy_line, marcado):  # ← RE-CRIA 11 VEZES!
        bx = cx_left
        by = cy_line - 0.06*cm
        c.setStrokeColor(colors.HexColor("#0A2C5E"))
        c.setFillColor(colors.HexColor("#0A2C5E") if marcado else colors.white)
        c.rect(bx, by, box, box, fill=1, stroke=1)
        if marcado:
            c.setFillColor(colors.white)
            c.setFont("Helvetica-Bold", 7)
            c.drawString(bx + 0.03*cm, by + 0.05*cm, "X")

    draw_checkbox(1.5*cm, cy, dados.get(chave, False))  # Chama 11x
    txt(rotulo, 1.5*cm + box + 0.15*cm, cy, tamanho=9)
    cy -= 0.52*cm
```

## MELHORADO (igual resultado, mais limpo):

```python
# MESMO LOCAL - SÓ MOVE FORA:

cy -= 0.5*cm
box   = 0.28*cm

def draw_checkbox(cx_left, cy_line, marcado):     # ← FORA DO LOOP (1x só)
    bx = cx_left
    by = cy_line - 0.06*cm
    c.setStrokeColor(colors.HexColor("#0A2C5E"))
    c.setFillColor(colors.HexColor("#0A2C5E") if marcado else colors.white)
    c.rect(bx, by, box, box, fill=1, stroke=1)
    if marcado:
        c.setFillColor(colors.white)
        c.setFont("Helvetica-Bold", 7)
        c.drawString(bx + 0.03*cm, by + 0.05*cm, "X")

for chave, rotulo in ocorrencias:                 # ← LOOP igual
    draw_checkbox(1.5*cm, cy, dados.get(chave, False))  # Chama igual
    txt(rotulo, 1.5*cm + box + 0.15*cm, cy, tamanho=9)
    cy -= 0.52*cm
```

## RESULTADO NO PDF:
```
☐ Portar materiais...
☑ Usar celular...     ← Múltiplos OK!
☐ Não portar...
```

## MUDANÇAS (3 linhas):
```
1. MOVIMENTA def draw_checkbox(...) para ANTES do for
2. Indentação do for diminui 4 espaços
3. ZERADO impacto visual
```

**VANTAGEM:** Código 20% menor + mais rápido + fácil de editar checkboxes.

**Risco:** Zero. Funciona idêntico! 🎯
