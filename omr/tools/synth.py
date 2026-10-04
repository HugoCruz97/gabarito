"""Gera cartões-resposta preenchidos sintéticos para testar o leitor, enquanto não temos
cartões reais. Simula caneta azul/preta, marcações imperfeitas e fotos de celular
(perspectiva, rotação, sombra, desfoque, ruído, compressão JPEG).

Uso: python -m tools.synth templates/x.pdf out/synth 20
"""
import json
import random
import sys
from pathlib import Path

import cv2
import fitz
import numpy as np

from omr.template import OPTIONS, build_template

PHOTO_DPI = 200  # a "foto" tem resolução diferente do modelo, como na vida real
PENS = {"azul": (150, 55, 25), "preta": (40, 35, 30)}  # BGR


def render_color(pdf: str, dpi: int) -> np.ndarray:
    pix = fitz.open(pdf)[0].get_pixmap(dpi=dpi, alpha=False)
    img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, 3)
    return cv2.cvtColor(img, cv2.COLOR_RGB2BGR)


def scribble(img, cx, cy, r, color, coverage=1.0, rng=random):
    """Preenche a bolinha como uma pessoa faria: rabiscos de caneta, não um disco perfeito."""
    layer = np.zeros(img.shape[:2], np.uint8)
    ox, oy = rng.uniform(-0.15, 0.15) * r, rng.uniform(-0.15, 0.15) * r
    rad = r * rng.uniform(0.8, 1.05) * coverage
    for _ in range(int(14 * coverage) + 4):
        a, b = rng.uniform(0, 2 * np.pi), rng.uniform(0, 2 * np.pi)
        p1 = (int(cx + ox + np.cos(a) * rad), int(cy + oy + np.sin(a) * rad))
        p2 = (int(cx + ox + np.cos(b) * rad), int(cy + oy + np.sin(b) * rad))
        cv2.line(layer, p1, p2, 255, max(2, int(r * 0.35)), cv2.LINE_AA)
    if coverage >= 0.9:
        cv2.circle(layer, (int(cx + ox), int(cy + oy)), int(rad * 0.85), 255, -1, cv2.LINE_AA)
    alpha = (layer.astype(np.float32) / 255 * rng.uniform(0.75, 0.95))[..., None]
    img[:] = (img * (1 - alpha) + np.array(color, np.float32) * alpha).astype(np.uint8)


def x_mark(img, cx, cy, r, color):
    d = int(r * 0.9)
    cv2.line(img, (int(cx - d), int(cy - d)), (int(cx + d), int(cy + d)), color, 2, cv2.LINE_AA)
    cv2.line(img, (int(cx - d), int(cy + d)), (int(cx + d), int(cy - d)), color, 2, cv2.LINE_AA)


def fill_sheet(pdf, template, rng):
    img = render_color(pdf, PHOTO_DPI)
    k = PHOTO_DPI / 150
    pen = rng.choice(list(PENS))
    color = PENS[pen]
    truth = {}

    for number, bubbles in template.questions.items():
        roll = rng.random()
        if roll < 0.04:
            truth[number] = {"kind": "blank", "marked": []}
            continue
        option = rng.choice(OPTIONS)
        b = bubbles[option]
        if roll < 0.08:  # duas marcações
            other = rng.choice([o for o in OPTIONS if o != option])
            for o in (option, other):
                bb = bubbles[o]
                scribble(img, bb.x * k, bb.y * k, bb.r * k, color, rng=rng)
            truth[number] = {"kind": "multiple", "marked": sorted([option, other])}
        elif roll < 0.11:  # marcação fraca/parcial
            scribble(img, b.x * k, b.y * k, b.r * k, color, coverage=0.55, rng=rng)
            truth[number] = {"kind": "partial", "marked": [option]}
        elif roll < 0.13:  # marcou com X (proibido no cartão)
            x_mark(img, b.x * k, b.y * k, b.r * k, color)
            truth[number] = {"kind": "x", "marked": [option]}
        else:
            scribble(img, b.x * k, b.y * k, b.r * k, color, rng=rng)
            truth[number] = {"kind": "ok", "marked": [option]}

    language = rng.choice(["ingles", "espanhol"])
    lb = template.language[language]
    scribble(img, lb.x * k, lb.y * k, lb.r * k, color, rng=rng)

    # Nome escrito à mão (rabisco), só para ter "sujeira" realista
    for i in range(rng.randint(8, 18)):
        x0, y0 = int((95 + i * 38) * k), int(530 * k)
        cv2.putText(img, chr(rng.randint(65, 90)), (x0, y0), cv2.FONT_HERSHEY_SCRIPT_SIMPLEX, 0.9 * k, color, 2, cv2.LINE_AA)

    return img, {"pen": pen, "language": language, "answers": truth}


def photograph(page, rng, severity=1.0):
    """Coloca a folha sobre uma mesa e 'fotografa' com celular."""
    h, w = page.shape[:2]
    pad = int(0.12 * max(w, h))
    canvas_w, canvas_h = w + 2 * pad, h + 2 * pad

    # mesa: textura de madeira/cinza com ruído
    base = np.array([rng.randint(60, 140), rng.randint(70, 130), rng.randint(80, 150)], np.float32)
    table = np.ones((canvas_h, canvas_w, 3), np.float32) * base
    grain = np.random.default_rng(rng.randint(0, 10**6)).normal(0, 25, (canvas_h, canvas_w)).astype(np.float32)
    table += cv2.GaussianBlur(grain, (0, 0), 6)[..., None]

    src = np.float32([[0, 0], [w, 0], [w, h], [0, h]])
    jitter = 0.06 * severity
    dst = np.float32([[pad + x + rng.uniform(-jitter, jitter) * w, pad + y + rng.uniform(-jitter, jitter) * h] for x, y in src])
    # rotação extra
    angle = np.deg2rad(rng.uniform(-8, 8) * severity)
    c = dst.mean(axis=0)
    rot = np.array([[np.cos(angle), -np.sin(angle)], [np.sin(angle), np.cos(angle)]], np.float32)
    dst = (dst - c) @ rot.T + c

    M = cv2.getPerspectiveTransform(src, dst)
    warped = cv2.warpPerspective(page, M, (canvas_w, canvas_h), borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    mask = cv2.warpPerspective(np.ones((h, w), np.float32), M, (canvas_w, canvas_h))[..., None]
    img = warped.astype(np.float32) * mask + table * (1 - mask)

    # iluminação irregular + sombra da mão/celular
    yy, xx = np.mgrid[0:canvas_h, 0:canvas_w].astype(np.float32)
    gx, gy = rng.uniform(-1, 1), rng.uniform(-1, 1)
    light = 1 - 0.25 * severity * ((xx / canvas_w - 0.5) * gx + (yy / canvas_h - 0.5) * gy + 0.5)
    if rng.random() < 0.6:
        sx, sy, sr = rng.uniform(0, canvas_w), rng.uniform(0, canvas_h), rng.uniform(0.2, 0.5) * canvas_w
        shadow = np.exp(-(((xx - sx) ** 2 + (yy - sy) ** 2) / (2 * sr ** 2)))
        light *= 1 - 0.35 * severity * shadow
    img *= light[..., None]

    # tom quente/frio da lâmpada
    img *= np.array([rng.uniform(0.85, 1.0), rng.uniform(0.9, 1.0), rng.uniform(0.95, 1.1)], np.float32)

    img = cv2.GaussianBlur(img, (0, 0), rng.uniform(0.4, 1.4) * severity)
    img += np.random.default_rng(rng.randint(0, 10**6)).normal(0, 4 * severity, img.shape).astype(np.float32)
    img = np.clip(img, 0, 255).astype(np.uint8)

    # resolução de celular comum + JPEG
    scale = rng.uniform(0.75, 1.0)
    img = cv2.resize(img, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    ok, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, rng.randint(60, 85)])
    return cv2.imdecode(buf, cv2.IMREAD_COLOR)


def main(pdf, out_dir, count, seed=42, severity=1.0):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    template = build_template(pdf)
    rng = random.Random(seed)
    for i in range(count):
        page, truth = fill_sheet(pdf, template, rng)
        photo = photograph(page, rng, severity)
        name = f"cartao_{i:03d}"
        cv2.imwrite(str(out / f"{name}.jpg"), photo)
        (out / f"{name}.json").write_text(json.dumps(truth, ensure_ascii=False, indent=1))
    print(f"{count} cartões gerados em {out}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 10,
         severity=float(sys.argv[4]) if len(sys.argv) > 4 else 1.0)
