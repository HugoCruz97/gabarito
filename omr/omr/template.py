"""Modelo do cartão-resposta: renderiza o PDF em branco e localiza cada bolinha.

O cartão não tem marcadores de canto, então o próprio PDF em branco é a referência:
- a foto é alinhada a ele (ver align.py);
- a intensidade de cada bolinha vazia (que já tem a letra impressa dentro) serve de base
  para medir o quanto ela foi preenchida.
"""
from dataclasses import dataclass, field

import cv2
import fitz  # PyMuPDF
import numpy as np

DPI = 150
OPTIONS = "ABCDE"


@dataclass
class Bubble:
    x: float
    y: float
    r: float


@dataclass
class Template:
    image: np.ndarray                      # cinza, uint8
    questions: dict[int, dict[str, Bubble]]
    language: dict[str, Bubble] = field(default_factory=dict)

    @property
    def size(self):
        h, w = self.image.shape[:2]
        return w, h


def render_pdf(path: str, dpi: int = DPI) -> np.ndarray:
    page = fitz.open(path)[0]
    pix = page.get_pixmap(dpi=dpi, colorspace=fitz.csGRAY, alpha=False)
    return np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width).copy()


def find_circles(gray: np.ndarray, min_r: float, max_r: float) -> list[Bubble]:
    """Contornos externos quase circulares dentro da faixa de raio esperada."""
    binary = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 25, 10)
    # RETR_LIST: as bolinhas ficam dentro da moldura da folha, então não são contornos "externos"
    contours, _ = cv2.findContours(binary, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    circles: list[Bubble] = []
    for c in sorted(contours, key=cv2.contourArea, reverse=True):
        area = cv2.contourArea(c)
        perimeter = cv2.arcLength(c, True)
        if perimeter == 0 or area == 0:
            continue
        circularity = 4 * np.pi * area / perimeter ** 2
        (x, y), r = cv2.minEnclosingCircle(c)
        if not (min_r <= r <= max_r and circularity > 0.7):
            continue
        # o anel da bolinha gera um contorno externo e um interno: fica só o maior
        if any(abs(b.x - x) < max_r and abs(b.y - y) < max_r for b in circles):
            continue
        circles.append(Bubble(x, y, r))
    return circles


def cluster(values: list[float], gap: float) -> list[list[int]]:
    """Agrupa índices cujos valores (ordenados) distam menos que `gap`."""
    order = sorted(range(len(values)), key=lambda i: values[i])
    groups: list[list[int]] = []
    for i in order:
        if groups and values[i] - values[groups[-1][-1]] < gap:
            groups[-1].append(i)
        else:
            groups.append([i])
    return groups


def build_template(pdf_path: str, dpi: int = DPI, expected_questions: int = 40) -> Template:
    gray = render_pdf(pdf_path, dpi)
    h, w = gray.shape
    scale = dpi / 150
    circles = find_circles(gray, 8 * scale, 14 * scale)

    # Região da folha de respostas: metade de baixo, à esquerda do robô
    answers = [c for c in circles if c.y > 0.57 * h and c.x < 0.63 * w]
    language = [c for c in circles if 0.53 * h < c.y < 0.57 * h]

    rows = cluster([c.y for c in answers], 10 * scale)
    questions: dict[int, dict[str, Bubble]] = {}
    row_bubbles = [sorted((answers[i] for i in row), key=lambda c: c.x) for row in rows]

    # Cada linha tem até 3 blocos de 5 bolinhas (colunas 1–15, 16–30, 31–40)
    blocks_per_row = []
    for bubbles in row_bubbles:
        blocks = [bubbles[i:i + 5] for i in range(0, len(bubbles), 5)]
        if any(len(b) != 5 for b in blocks):
            raise ValueError(f"Linha com {len(bubbles)} bolinhas; esperado múltiplo de 5")
        blocks_per_row.append(blocks)

    rows_count = len(blocks_per_row)
    for row_index, blocks in enumerate(blocks_per_row):
        for col_index, block in enumerate(blocks):
            number = col_index * rows_count + row_index + 1
            questions[number] = dict(zip(OPTIONS, block))

    if len(questions) != expected_questions:
        raise ValueError(f"Encontradas {len(questions)} questões; esperado {expected_questions}")

    lang = sorted(language, key=lambda c: c.x)
    return Template(gray, dict(sorted(questions.items())), dict(zip(["ingles", "espanhol"], lang)))


def draw(template: Template) -> np.ndarray:
    out = cv2.cvtColor(template.image, cv2.COLOR_GRAY2BGR)
    for number, bubbles in template.questions.items():
        for option, b in bubbles.items():
            cv2.circle(out, (round(b.x), round(b.y)), round(b.r), (0, 160, 0), 2)
        a = bubbles["A"]
        cv2.putText(out, str(number), (round(a.x - 70), round(a.y + 5)), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 0, 255), 1)
    for b in template.language.values():
        cv2.circle(out, (round(b.x), round(b.y)), round(b.r), (255, 0, 0), 2)
    return out


if __name__ == "__main__":
    import sys

    t = build_template(sys.argv[1])
    radii = [b.r for q in t.questions.values() for b in q.values()]
    print(f"{len(t.questions)} questões, raio médio {np.mean(radii):.1f}px, língua: {list(t.language)}")
    print("Q1:", {k: (round(v.x), round(v.y)) for k, v in t.questions[1].items()})
    print("Q40:", {k: (round(v.x), round(v.y)) for k, v in t.questions[40].items()})
    cv2.imwrite("out/template_debug.png", draw(t))
