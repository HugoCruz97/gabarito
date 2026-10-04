"""Roda o leitor nos cartões sintéticos e compara com o gabarito real de cada um.

Uso: python -m tools.evaluate templates/x.pdf out/synth
"""
import json
import sys
import time
from collections import Counter
from pathlib import Path

import cv2

from omr.align import AlignmentError
from omr.reader import draw_result, read_sheet
from omr.template import build_template

# O que o leitor DEVE fazer em cada tipo de marcação
EXPECTED = {
    "ok": lambda t, q: q["status"] == "ok" and q["answer"] == t["marked"][0],
    "blank": lambda t, q: q["status"] == "blank",
    "multiple": lambda t, q: q["status"] == "multiple",
    # marca fraca: ler a letra certa OU mandar para revisão; nunca outra letra e nunca
    # "em branco" (o aluno perderia o ponto sem ninguém perceber)
    "partial": lambda t, q: q["answer"] == t["marked"][0] or q["status"] in ("doubtful", "multiple"),
    # X é proibido: o certo é mandar para revisão (ou ler a letra certa), nunca outra letra
    "x": lambda t, q: q["status"] in ("doubtful", "blank") or q["answer"] == t["marked"][0],
}


def main(pdf, folder):
    template = build_template(pdf)
    debug = Path(folder) / "debug"
    debug.mkdir(exist_ok=True)

    totals, errors, silent_wrong = Counter(), Counter(), 0
    review_counts, lang_ok, failures, times = [], 0, 0, []

    files = sorted(Path(folder).glob("*.jpg"))
    for photo_path in files:
        truth = json.loads(photo_path.with_suffix(".json").read_text())
        start = time.perf_counter()
        try:
            result = read_sheet(cv2.imread(str(photo_path)), template)
        except AlignmentError as e:
            failures += 1
            print(f"{photo_path.name}: FALHOU ({e})")
            continue
        times.append(time.perf_counter() - start)

        cv2.imwrite(str(debug / photo_path.name), draw_result(result, template))
        lang_ok += result["language"] == truth["language"]
        review_counts.append(len(result["needs_review"]))

        for q in result["questions"]:
            t = truth["answers"][str(q["number"])]
            totals[t["kind"]] += 1
            if not EXPECTED[t["kind"]](t, q):
                errors[t["kind"]] += 1
                # o pior erro: o sistema dá uma resposta errada SEM pedir revisão
                if q["status"] == "ok":
                    silent_wrong += 1
                print(f"  {photo_path.name} Q{q['number']:>2} esperado {t['kind']} {t['marked']} → lido {q['status']} {q['answer']} {q['fills']}")

    n = len(files) - failures
    print(f"\nCartões: {len(files)} | alinhados: {n} | falhas de alinhamento: {failures}")
    print(f"Tempo médio por cartão: {sum(times) / max(len(times), 1):.2f}s")
    print(f"Língua correta: {lang_ok}/{n}")
    for kind in ("ok", "blank", "multiple", "partial", "x"):
        if totals[kind]:
            acc = 100 * (1 - errors[kind] / totals[kind])
            print(f"  {kind:<9} {totals[kind]:>5} questões  acerto {acc:6.2f}%")
    total = sum(totals.values())
    print(f"Geral: {100 * (1 - sum(errors.values()) / total):.2f}% | respostas erradas sem pedir revisão: {silent_wrong}")
    print(f"Questões enviadas para revisão por cartão: média {sum(review_counts) / max(n, 1):.1f}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
