"""Compare exports from Flutter/Edge Function with the actual V1 generator.

Generate fixtures first with PDF_QA_DIR for occurrence_pdf_test.dart and
occurrence-pdf_test.ts, then run this script with that directory as argument.
Requires reportlab, Pillow and pypdf. Only synthetic records are used.
"""
import ast
import base64
from datetime import datetime
import io
import json
import os
from pathlib import Path
import sys
from types import SimpleNamespace
from PIL import Image
from pypdf import PdfReader
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase.pdfmetrics import stringWidth
from reportlab.pdfgen import canvas as rl_canvas

root = Path(__file__).resolve().parent.parent
out = Path(sys.argv[1])
source = ast.parse((root / 'v1-desktop/ocorrenciaescolar.py').read_text())
selected = []
for node in source.body:
    if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name) and node.targets[0].id in {'OCORRENCIAS', 'PROVIDENCIAS', 'LOGO_SP_B64'}:
        selected.append(node)
    elif isinstance(node, ast.FunctionDef) and node.name == 'gerar_pdf':
        selected.append(node)
class FrozenDate(datetime):
    @classmethod
    def now(cls):
        return cls(2026, 9, 9, 12)
# Execute only the original renderer/constants; never import the desktop UI or Gmail.
env = dict(globals(), datetime=FrozenDate, _b64=base64,
           os=SimpleNamespace(makedirs=os.makedirs, path=SimpleNamespace(
               join=os.path.join, expanduser=lambda _: str(out))))
exec(compile(ast.Module(body=selected, type_ignores=[]), '<V1 PDF reference>', 'exec'), env)
cases = json.loads((root / 'v2-mobile/test/fixtures/pdf_v1.json').read_text())

def spans(page):
    # Read each text-show operation directly: extract_text visitor callbacks can
    # be deferred until after the next BT and report a reset text matrix.
    found = []
    x = y = size = 0
    for args, op in page.get_contents().operations:
        if op == b'BT': x = y = 0
        elif op == b'Tf': size = float(args[1])
        elif op == b'Tm': x, y = float(args[4]), float(args[5])
        elif op == b'Td': x += float(args[0]); y += float(args[1])
        elif op in {b'Tj', b'TJ'}:
            chunks = args[0] if op == b'TJ' else [args[0]]
            text = ''.join(c.original_bytes.decode('cp1252') for c in chunks if isinstance(c, str)).strip()
            if text: found.append((text, x, y, size))
    return found

def locate(items, label):
    return next(item for item in items if item[0] == label)

for name, record in cases.items():
    mobile = PdfReader(out / f'flutter-{name}.pdf')
    server = PdfReader(out / f'server-{name}.pdf')
    expected = 2 if name in {'limites', 'cancelada'} else 1
    assert len(mobile.pages) == len(server.pages) == expected, name
    mobile_text = '\n'.join(p.extract_text() for p in mobile.pages)
    server_text = '\n'.join(p.extract_text() for p in server.pages)
    # Every text and its coordinates must match between the two engines.
    for mp, sp in zip(mobile.pages, server.pages):
        ms, ss = spans(mp), spans(sp)
        assert [s[0] for s in ms] == [s[0] for s in ss], f'{name}: engine text mismatch'
        for a, b in zip(ms, ss):
            assert max(abs(a[i] - b[i]) for i in range(1, 4)) < .06, (name, a, b)
        assert len(mp.images) == len(sp.images) == 1, 'Original logo missing'
        assert abs(float(mp.mediabox.width) - A4[0]) < .01
        for text, x, y, size in ms:
            assert y > 0 and x >= 0, (name, text, x, y)
    assert sum(item[0] == 'X' for item in spans(mobile.pages[0])) == len(record['providencias']) + len(record['motivos']), 'Incorrect checkbox selection'
    for text in [record['students']['nome'], record['professor'], record['relato']]:
        # Whitespace may be inserted into long words at visual line breaks.
        assert ''.join(text.split()) in ''.join(mobile_text.split()), (name, 'lost content')
    if name == 'limites':
        assert ''.join(record['motivos'][0][7:].split()) in ''.join(mobile_text.split())
    if name == 'cancelada':
        assert mobile_text.count('CANCELADA') == expected
        assert record['change_reason'] in mobile_text
    if name not in {'normal', 'outro'}:
        continue
    data = dict(aluno=record['students']['nome'], serie=record['students']['turma'],
                data='09/09/2026', relatado_por=record['professor'], relato=record['relato'])
    for key, label in env['OCORRENCIAS']:
        data[key] = label in record['motivos'] or (key == 'oc11' and name == 'outro')
    if name == 'outro': data['outra_desc'] = record['motivos'][0][7:]
    for key, label in env['PROVIDENCIAS']: data[key] = label in record['providencias']
    generated = Path(env['gerar_pdf'](data))
    target = out / f'v1-{name}.pdf'
    generated.replace(target)
    original = PdfReader(target)
    ref, actual = spans(original.pages[0]), spans(mobile.pages[0])
    def boxes(page):
        return sorted(set(tuple(round(float(x), 3) for x in args) for args, op in page.get_contents().operations if op == b're' and 7 < float(args[2]) < 9 and 7 < float(args[3]) < 9))
    assert len(boxes(original.pages[0])) == 17
    assert len(boxes(mobile.pages[0])) == 17
    for a, b in zip(boxes(original.pages[0]), boxes(mobile.pages[0])):
        assert max(abs(x-y) for x,y in zip(a,b)) < .002, 'Checkbox geometry differs from V1'
    # V1 ReportLab emits multiline chunks/glyph fallback for the arrow; compare
    # institutional headings, all options, signature baselines and field positions.
    labels = ['SECRETARIA DE ESTADO DA EDUCAÇÃO', 'FICHA DE OCORRÊNCIA DISCIPLINAR',
              'IDENTIFICAÇÃO', 'OCORRÊNCIA', 'RELATO DA OCORRÊNCIA',
              'PROVIDÊNCIA TOMADA PELA EQUIPE GESTORA',
              'Assinatura do Aluno', 'Assinatura do Responsável', 'Assinatura da Equipe Gestora',
              record['students']['nome'], record['professor']]
    labels += [label for _, label in env['OCORRENCIAS'] + env['PROVIDENCIAS']]
    for label in labels:
        a, b = locate(ref, label), locate(actual, label)
        assert max(abs(a[i] - b[i]) for i in range(1, 4)) < .06, (name, label, a, b)
    assert original.pages[0].images[0].image.tobytes() == mobile.pages[0].images[0].image.convert('RGB').tobytes(), 'Logo differs from V1'
    print(f'{name}: V1 typography, coordinates, labels and original logo match')
print('All 5 cases: Flutter/server parity, pagination and complete content passed.')
