"""Lê as marcações de um cartão-resposta fotografado ou escaneado.

Para cada bolinha mede o "preenchimento": quanto ela está mais escura que a mesma
bolinha no cartão em branco (que já tem a letra impressa). Depois decide por questão:
- uma bolinha claramente preenchida → resposta;
- nenhuma → em branco;
- duas ou mais → marcação múltipla (vale zero);
- algo no meio do caminho → "duvidosa", para a professora revisar.
"""
from dataclasses import dataclass, asdict

import cv2
import numpy as np

from .align import align, normalize_lighting
from .template import OPTIONS, Template

MARKED = 0.38    # acima disto a bolinha está preenchida
DOUBTFUL = 0.18  # entre DOUBTFUL e MARKED: pode ser marca fraca, rasura ou X


@dataclass
class QuestionResult:
    number: int
    answer: str | None          # "A".."E" ou None
    status: str                 # ok | blank | multiple | doubtful
    confidence: float           # 0..1
    fills: dict[str, float]


def disc_mean(img: np.ndarray, x: float, y: float, r: float) -> float:
    x0, y0, x1, y1 = int(x - r), int(y - r), int(x + r) + 1, int(y + r) + 1
    patch = img[y0:y1, x0:x1].astype(np.float32)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    mask = (xx - x) ** 2 + (yy - y) ** 2 <= r * r
    return float(patch[mask].mean())


def bubble_fill(photo: np.ndarray, blank: np.ndarray, x: float, y: float, r: float) -> float:
    """0 = igual ao cartão em branco, 1 = totalmente preto. Procura num raio pequeno
    em volta do centro esperado para tolerar erro residual de alinhamento."""
    inner = r * 0.72
    base = disc_mean(blank, x, y, inner)
    best = 0.0
    for dx in (-2, 0, 2):
        for dy in (-2, 0, 2):
            value = disc_mean(photo, x + dx, y + dy, inner)
            fill = (base - value) / max(base, 1)
            best = max(best, fill)
    return float(np.clip(best, 0, 1))


def decide(number: int, fills: dict[str, float]) -> QuestionResult:
    ranked = sorted(fills.items(), key=lambda kv: kv[1], reverse=True)
    (top, f1), (_, f2) = ranked[0], ranked[1]
    marked = [o for o, f in ranked if f >= MARKED]

    if len(marked) >= 2:
        return QuestionResult(number, None, "multiple", round(min(1.0, f2 / MARKED), 2), fills)
    if len(marked) == 1:
        # confiança: quão acima do limiar e quão acima da segunda colocada
        margin = min((f1 - MARKED) / (1 - MARKED), (f1 - f2) / f1)
        status = "doubtful" if f2 >= DOUBTFUL else "ok"
        return QuestionResult(number, top, status, round(float(np.clip(0.5 + margin, 0, 1)), 2), fills)
    if f1 >= DOUBTFUL:
        return QuestionResult(number, top, "doubtful", round(f1 / MARKED * 0.5, 2), fills)
    return QuestionResult(number, None, "blank", round(1 - f1 / DOUBTFUL * 0.5, 2), fills)


def answer_box(template: Template, pad: int = 30) -> tuple[int, int, int, int]:
    pts = [(b.x, b.y) for q in template.questions.values() for b in q.values()] + [(b.x, b.y) for b in template.language.values()]
    xs, ys = zip(*pts)
    return int(min(xs) - pad), int(min(ys) - pad), int(max(xs) + pad), int(max(ys) + pad)


def read_sheet(image: np.ndarray, template: Template) -> dict:
    warped, info = align(image, template.image, answer_box(template))
    photo = normalize_lighting(warped)
    blank = normalize_lighting(template.image)

    raw = {n: {o: bubble_fill(photo, blank, b.x, b.y, b.r) for o, b in bubbles.items()}
           for n, bubbles in template.questions.items()}

    # Calibração por foto: a grande maioria das bolinhas está vazia, então a mediana diz
    # quanto uma bolinha VAZIA escurece nesta foto (desfoque, contraste, papel, luz).
    baseline = float(np.median([f for q in raw.values() for f in q.values()]))

    def calibrated(f):
        return round(float(np.clip((f - baseline) / (1 - baseline), 0, 1)), 3)

    results = [decide(n, {o: calibrated(f) for o, f in fills.items()}) for n, fills in raw.items()]

    lang_fills = {k: calibrated(bubble_fill(photo, blank, b.x, b.y, b.r)) for k, b in template.language.items()}
    lang_marked = [k for k, f in lang_fills.items() if f >= MARKED]

    return {
        "alignment": {**info, "baseline": round(baseline, 3)},
        "language": lang_marked[0] if len(lang_marked) == 1 else None,
        "questions": [asdict(r) for r in results],
        "needs_review": [r.number for r in results if r.status in ("doubtful", "multiple")],
        "_warped": warped,
    }


def draw_result(result: dict, template: Template) -> np.ndarray:
    """Imagem de conferência: verde = lida, laranja = duvidosa, vermelho = múltipla."""
    out = cv2.cvtColor(result["_warped"], cv2.COLOR_GRAY2BGR)
    colors = {"ok": (60, 170, 0), "doubtful": (0, 150, 255), "multiple": (40, 40, 230), "blank": (180, 180, 180)}
    for q in result["questions"]:
        bubbles = template.questions[q["number"]]
        color = colors[q["status"]]
        for option, fill in q["fills"].items():
            b = bubbles[option]
            if fill >= DOUBTFUL or option == q["answer"]:
                cv2.circle(out, (round(b.x), round(b.y)), round(b.r + 3), color, 2)
        if q["status"] == "blank":
            a = bubbles["A"]
            cv2.line(out, (round(a.x - 14), round(a.y)), (round(bubbles["E"].x + 14), round(a.y)), color, 1)
    return out
