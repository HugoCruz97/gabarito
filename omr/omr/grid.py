"""Leitura sem modelo fixo: descobre a grade de bolinhas na própria foto.

A escola muda o cartão a cada simulado (40 questões A–E, 25 questões A–D, ...), mas o
desenho segue o mesmo padrão: blocos de colunas com N linhas, numerados de cima para
baixo e da esquerda para a direita. Com a quantidade de questões e de alternativas que
o simulado informa, o leitor:

1. endireita a folha pela maior borda retangular (papel ou moldura do cartão);
2. acha as bolinhas vazias (contornos circulares do tamanho mais comum);
3. agrupa as posições em colunas de alternativas e em linhas; bolinhas preenchidas que
   não aparecem como círculo são deduzidas pela regularidade da grade;
4. mede o preenchimento de cada posição comparando com as demais bolinhas da foto.
"""
from dataclasses import dataclass

import cv2
import numpy as np

from .align import normalize_lighting, to_gray
from .reader import DOUBTFUL, MARKED, decide

OPTIONS = "ABCDE"
WIDTH = 1240  # largura de trabalho (equivale a A4 em 150 dpi)


class GridError(Exception):
    pass


@dataclass
class Circle:
    x: float
    y: float
    r: float


# ---------------------------------------------------------------- folha

def order_corners(pts: np.ndarray) -> np.ndarray:
    s, d = pts.sum(axis=1), np.diff(pts, axis=1).ravel()
    return np.float32([pts[np.argmin(s)], pts[np.argmin(d)], pts[np.argmax(s)], pts[np.argmax(d)]])


def rectify(gray: np.ndarray) -> tuple[np.ndarray, str]:
    """Primeira opção de endireitamento (usada em diagnósticos)."""
    return next(rectify_candidates(gray))


def rectify_candidates(gray: np.ndarray):
    """Maneiras de endireitar a folha, da mais confiável para a mais aproximada.
    Quem escolhe é build_grid: vale a primeira que produz uma grade válida."""
    h, w = gray.shape
    small_scale = 1000 / max(h, w)
    small = cv2.resize(gray, None, fx=small_scale, fy=small_scale, interpolation=cv2.INTER_AREA)
    edges = cv2.Canny(cv2.GaussianBlur(small, (5, 5), 0), 40, 120)
    edges = cv2.dilate(edges, np.ones((3, 3), np.uint8))
    contours, _ = cv2.findContours(edges, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)

    area_min = 0.25 * small.shape[0] * small.shape[1]
    big = [c for c in sorted(contours, key=cv2.contourArea, reverse=True)[:10] if cv2.contourArea(c) >= area_min]

    def warp(corners: np.ndarray, method: str):
        src = order_corners(corners.astype(np.float32) / small_scale)
        top, left = np.linalg.norm(src[1] - src[0]), np.linalg.norm(src[3] - src[0])
        bottom, right = np.linalg.norm(src[2] - src[3]), np.linalg.norm(src[2] - src[1])
        height = int(WIDTH * ((left + right) / 2) / ((top + bottom) / 2))
        dst = np.float32([[0, 0], [WIDTH, 0], [WIDTH, height], [0, height]])
        M = cv2.getPerspectiveTransform(src, dst)
        return cv2.warpPerspective(gray, M, (WIDTH, height), flags=cv2.INTER_CUBIC, borderValue=255), method

    def quads(epsilon):
        for c in big:
            approx = cv2.approxPolyDP(c, epsilon * cv2.arcLength(c, True), True)
            if len(approx) == 4:
                yield approx.reshape(4, 2)

    # 1º: quadrilátero bem definido (papel ou moldura) — corrige perspectiva e rotação
    for quad in quads(0.02):
        yield warp(quad, "borda")

    # 2º: a foto como está (folha já quase reta, ou borda fora do enquadramento)
    scale = WIDTH / w
    yield cv2.resize(gray, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC), "sem borda"

    # 3º: bordas irregulares (sombra, papel dobrado) e, por fim, só a rotação
    for epsilon in (0.04, 0.06):
        for quad in quads(epsilon):
            yield warp(quad, "borda aproximada")
    if big:
        yield warp(cv2.boxPoints(cv2.minAreaRect(big[0])), "rotação")


# ---------------------------------------------------------------- bolinhas

def find_circles(img: np.ndarray, min_r: float, max_r: float, min_circularity: float = 0.65) -> list[Circle]:
    binary = cv2.adaptiveThreshold(img, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 31, 10)
    contours, _ = cv2.findContours(binary, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    found: list[Circle] = []
    for c in sorted(contours, key=cv2.contourArea, reverse=True):
        area, perimeter = cv2.contourArea(c), cv2.arcLength(c, True)
        if area <= 0 or perimeter <= 0:
            continue
        (x, y), r = cv2.minEnclosingCircle(c)
        if not (min_r <= r <= max_r) or 4 * np.pi * area / perimeter ** 2 < min_circularity:
            continue
        if any(abs(f.x - x) < f.r and abs(f.y - y) < f.r for f in found):
            continue  # anel interno/externo da mesma bolinha
        found.append(Circle(x, y, r))
    return found


def cluster_1d(values: list[float], gap: float) -> list[list[int]]:
    order = sorted(range(len(values)), key=lambda i: values[i])
    groups: list[list[int]] = []
    for i in order:
        if groups and values[i] - values[groups[-1][-1]] <= gap:
            groups[-1].append(i)
        else:
            groups.append([i])
    return groups


def typical_radius(circles: list[Circle]) -> float:
    radii = np.array([c.r for c in circles])
    hist, edges = np.histogram(radii, bins=np.arange(radii.min(), radii.max() + 1.0, 1.0))
    peak = edges[np.argmax(hist)] + 0.5
    near = radii[np.abs(radii - peak) <= 1.5]
    return float(np.median(near))


def build_grid(img: np.ndarray, questions: int, options: int):
    """Retorna (questões {n: [(x, y), ...]}, raio, linhas_y, espaçamento)."""
    width = img.shape[1]
    circles = find_circles(img, 0.005 * width, 0.025 * width)
    if len(circles) < questions:
        raise GridError("Não encontrei as bolinhas do cartão. A foto está nítida e com o cartão inteiro?")

    r = typical_radius(circles)
    bubbles = [c for c in circles if 0.75 * r <= c.r <= 1.3 * r]

    # Colunas de alternativas: posições x que se repetem em várias linhas.
    # Cada coluna vira uma reta x = a·y + b (a folha pode estar levemente girada).
    xs = [b.x for b in bubbles]
    columns = []
    for g in cluster_1d(xs, 0.8 * r):
        if len(g) >= 3:
            pts = [bubbles[i] for i in g]
            a, b = np.polyfit([p.y for p in pts], [p.x for p in pts], 1) if len(pts) >= 4 else (0.0, np.mean([p.x for p in pts]))
            columns.append({"pts": pts, "a": float(a), "b": float(b), "x": float(np.mean([p.x for p in pts]))})
    if len(columns) < options:
        raise GridError("Não consegui identificar as colunas de alternativas.")

    # Separa as colunas em blocos de `options`: as alternativas de uma questão têm
    # espaçamento constante; colunas fora desse ritmo (ex.: o "0" de "30" impresso
    # entre os blocos) quebram a sequência e ficam de fora.
    col_x = [c["x"] for c in columns]
    gaps = np.diff(col_x)
    unit = float(np.median(np.sort(gaps)[: max(1, len(gaps) // 2 + 1)]))
    chains, current = [], [columns[0]]
    for col, gap in zip(columns[1:], gaps):
        if abs(gap - unit) > 0.25 * unit:
            chains.append(current)
            current = []
        current.append(col)
    chains.append(current)

    # Uma sequência maior que `options` tem uma coluna intrusa na ponta (um dígito do
    # número da questão logo antes do "A"): fica a janela com mais bolinhas detectadas.
    blocks = []
    for chain in chains:
        if len(chain) < options:
            continue
        windows = [chain[i:i + options] for i in range(len(chain) - options + 1)]
        blocks.append(max(windows, key=lambda w: sum(len(c["pts"]) for c in w)))
    if not blocks:
        raise GridError(f"Não encontrei blocos de {options} alternativas. O simulado tem {options} alternativas por questão?")

    def col_x_at(col, y):
        return col["a"] * y + col["b"]

    in_block = [b for b in bubbles if any(abs(b.x - col_x_at(c, b.y)) <= 0.8 * r for block in blocks for c in block)]

    # Linhas: alturas que se repetem nas colunas; cada linha vira uma reta y = c·x + d.
    # Fica só o grupo contínuo principal (descarta o exemplo das instruções etc.)
    ys = [b.y for b in in_block]
    rows = []
    for g in cluster_1d(ys, 0.8 * r):
        if len(g) >= 2:
            pts = [in_block[i] for i in g]
            c, d = np.polyfit([p.x for p in pts], [p.y for p in pts], 1) if len({round(p.x) for p in pts}) >= 3 else (0.0, np.mean([p.y for p in pts]))
            rows.append({"pts": pts, "c": float(c), "d": float(d), "y": float(np.mean([p.y for p in pts]))})
    if len(rows) < 2:
        raise GridError("Não consegui identificar as linhas de questões.")
    spacing = float(np.median(np.diff([row["y"] for row in rows])))
    runs, run = [], [rows[0]]
    for row, prev in zip(rows[1:], rows):
        if row["y"] - prev["y"] > 1.8 * spacing:
            runs.append(run)
            run = []
        run.append(row)
    runs.append(run)
    rows = max(runs, key=len)

    def intersect(col, row):
        # x = a·y + b  e  y = c·x + d
        y = (row["c"] * col["b"] + row["d"]) / (1 - row["c"] * col["a"])
        return col["a"] * y + col["b"], y

    # Numeração: bloco por bloco, de cima para baixo; uma linha existe no bloco se
    # tiver pelo menos 2 bolinhas visíveis (a marcada pode não aparecer como círculo)
    grid: dict[int, list[tuple[float, float]]] = {}
    number = 0
    for block in blocks:
        for row in rows:
            positions = [intersect(col, row) for col in block]
            hits = sum(1 for b in in_block for (x, y) in positions if abs(b.x - x) <= 0.8 * r and abs(b.y - y) <= 0.8 * r)
            if hits >= min(2, options - 1):
                number += 1
                grid[number] = positions

    if number != questions:
        raise GridError(f"Encontrei {number} questões na foto, mas o simulado tem {questions}. "
                        "Confira se é o cartão deste simulado e se ele aparece inteiro.")
    return grid, r, [row["y"] for row in rows], spacing


# ---------------------------------------------------------------- leitura

def darkness(img: np.ndarray, x: float, y: float, r: float) -> float:
    """Maior escurecimento médio num disco de raio r em volta de (x, y), com pequena folga."""
    best = 0.0
    step = max(1.0, 0.2 * r)
    for dx in (-step, 0, step):
        for dy in (-step, 0, step):
            cx, cy = x + dx, y + dy
            x0, y0, x1, y1 = int(cx - r), int(cy - r), int(cx + r) + 1, int(cy + r) + 1
            if x0 < 0 or y0 < 0 or y1 > img.shape[0] or x1 > img.shape[1]:
                continue
            patch = img[y0:y1, x0:x1].astype(np.float32)
            yy, xx = np.mgrid[y0:y1, x0:x1]
            mask = (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r
            best = max(best, 1 - float(patch[mask].mean()) / 255)
    return best


def find_language(img, grid_top: float, spacing: float, r: float):
    """As duas bolinhas Inglês/Espanhol ficam na linha logo acima da grade de respostas.

    Retorna ({"ingles": Circle, "espanhol": Circle}, língua marcada ou None).
    A bolinha rabiscada costuma ficar pouco redonda, por isso a circularidade aceita é
    baixa e o filtro é o tamanho (letras do texto ao lado são bem menores)."""
    width = img.shape[1]
    y0, y1 = int(max(0, grid_top - 3.5 * spacing)), int(grid_top - 0.2 * spacing)
    x0, x1 = int(0.2 * width), int(0.85 * width)  # ficam perto do centro da folha

    # Candidatas: bolinhas vazias (círculos) e rabiscadas (manchas escuras arredondadas,
    # que muitas vezes encostam no texto e deixam de ser um círculo limpo)
    candidates = [c for c in find_circles(img, 0.8 * r, 1.8 * r, min_circularity=0.5)
                  if y0 < c.y < y1 and x0 < c.x < x1]
    region = img[y0:y1, x0:x1]
    dark = (region < 140).astype(np.uint8)
    count, _, stats, centers = cv2.connectedComponentsWithStats(dark)
    for i in range(1, count):
        w, h, area = stats[i, cv2.CC_STAT_WIDTH], stats[i, cv2.CC_STAT_HEIGHT], stats[i, cv2.CC_STAT_AREA]
        if 0.5 * np.pi * r * r <= area <= 3 * np.pi * r * r and 1.4 * r <= min(w, h) and max(w, h) <= 3.5 * r:
            cx, cy = centers[i][0] + x0, centers[i][1] + y0
            if not any(abs(c.x - cx) < r and abs(c.y - cy) < r for c in candidates):
                candidates.append(Circle(cx, cy, max(w, h) / 2))

    # O par Inglês/Espanhol: mesma linha, distância de ~8–20% da largura entre eles,
    # tamanhos parecidos. Entre os pares válidos, o mais próximo da grade.
    pairs = []
    for i, a in enumerate(candidates):
        for b in candidates[i + 1:]:
            gap = abs(a.x - b.x)
            if abs(a.y - b.y) <= r and 0.08 * width <= gap <= 0.2 * width and max(a.r, b.r) / min(a.r, b.r) <= 1.6:
                pairs.append(sorted((a, b), key=lambda c: c.x))
    if not pairs:
        return {}, None
    left, right = max(pairs, key=lambda p: (p[0].y + p[1].y) / 2)
    circles = {"ingles": left, "espanhol": right}

    # Comparação entre as duas (sem letra impressa dentro, a régua das respostas não
    # serve): marcada é a claramente mais escura. Parecidas = ambas vazias ou ambas
    # marcadas → sem língua, e o cartão vai para revisão.
    dark = {name: darkness(img, c.x, c.y, c.r * 0.72) for name, c in circles.items()}
    (light_name, lo), (dark_name, hi) = sorted(dark.items(), key=lambda kv: kv[1])
    marked = dark_name if hi - lo >= 0.15 and (hi - lo) / (1 - lo) >= 0.25 else None
    return circles, marked


def read_sheet_auto(image: np.ndarray, questions: int, options: int) -> dict:
    error = None
    for rectified, method in rectify_candidates(to_gray(image)):
        norm = normalize_lighting(rectified)
        try:
            grid, r, row_y, spacing = build_grid(norm, questions, options)
            break
        except GridError as e:
            error = error or e  # guarda o erro da tentativa mais confiável
    else:
        raise error

    letters = OPTIONS[:options]
    raw = {n: {letter: darkness(norm, x, y, r * 0.72) for letter, (x, y) in zip(letters, pos)} for n, pos in grid.items()}

    # Calibração por letra: "B" e "D" impressos têm mais tinta que "A" e "C", então uma
    # bolinha vazia de cada letra escurece diferente. Como a maioria das bolinhas de cada
    # letra está vazia, a mediana daquela letra na foto é o "vazio" dela. A bolinha mais
    # escura de cada questão (a provável marcada) fica de fora, senão uma letra que é
    # resposta de muitas questões "puxaria" a própria referência para cima.
    empties = {o: [d for q in raw.values() for opt, d in q.items() if opt == o and d < max(q.values())] for o in letters}
    baseline_by_option = {o: float(np.median(empties[o] or [q[o] for q in raw.values()])) for o in letters}
    baseline = float(np.median(list(baseline_by_option.values())))

    def calibrate(d, base=baseline):
        return round(float(np.clip((d - base) / (1 - base), 0, 1)), 3)

    fills = {n: {o: calibrate(d, baseline_by_option[o]) for o, d in q.items()} for n, q in raw.items()}

    # Ajuste local: sombra ou desfoque num canto da foto escurece todas as bolinhas de uma
    # linha. A mediana das bolinhas da questão sem a mais escura é o "vazio" daquela linha.
    for n, q in fills.items():
        rest = sorted(q.values())[:-1]
        local = float(np.median(rest)) if rest else 0.0
        if local > 0:
            fills[n] = {o: round(float(np.clip((f - local) / (1 - local), 0, 1)), 3) for o, f in q.items()}

    # Limites relativos à foto: quão escura fica uma bolinha marcada NESTA foto
    # (caneta, luz e nitidez mudam muito entre fotos). Mediana da mais escura de cada
    # questão, já que a grande maioria das questões é respondida.
    tops = [max(q.values()) for q in fills.values()]
    typical = float(np.median([t for t in tops if t >= 0.15] or [MARKED * 2]))
    marked_at = float(np.clip(0.5 * typical, 0.2, MARKED))
    doubtful_at = 0.5 * marked_at

    results = [decide(n, f, marked_at, doubtful_at) for n, f in fills.items()]
    language_circles, language = find_language(norm, min(row_y), spacing, r)

    return {
        "alignment": {"method": method, "radius": round(r, 1), "baseline": round(baseline, 3),
                      "marked_at": round(marked_at, 3)},
        "language": language,
        "questions": [vars(q) for q in results],
        "needs_review": [q.number for q in results if q.status in ("doubtful", "multiple")],
        "_image": rectified,
        "_grid": grid,
        "_radius": r,
        "_language": language_circles,
    }


def draw_auto(result: dict) -> np.ndarray:
    """Imagem de conferência: verde = lida, laranja = duvidosa, vermelho = múltipla."""
    out = cv2.cvtColor(result["_image"], cv2.COLOR_GRAY2BGR)
    r = result["_radius"]
    colors = {"ok": (60, 170, 0), "doubtful": (0, 150, 255), "multiple": (40, 40, 230), "blank": (180, 180, 180)}
    for q in result["questions"]:
        positions = result["_grid"][q["number"]]
        color = colors[q["status"]]
        for (option, fill), (x, y) in zip(q["fills"].items(), positions):
            if fill >= DOUBTFUL or option == q["answer"]:
                cv2.circle(out, (round(x), round(y)), round(r + 3), color, 2)
        if q["status"] == "blank":
            (x0, y0), (x1, _) = positions[0], positions[-1]
            cv2.line(out, (round(x0 - r - 3), round(y0)), (round(x1 + r + 3), round(y0)), color, 1)
    for name, c in result["_language"].items():
        selected = result["language"] == name
        cv2.circle(out, (round(c.x), round(c.y)), round(c.r + 3), (60, 170, 0) if selected else (180, 180, 180), 2)
    return out


def public(result: dict) -> dict:
    return {k: v for k, v in result.items() if not k.startswith("_")}
