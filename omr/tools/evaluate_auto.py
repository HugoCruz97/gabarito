"""Avalia o leitor automático de grade (sem modelo) nos cartões sintéticos.

Uso: python -m tools.evaluate_auto out/synth 40 5
"""
import json
import sys
import time
from collections import Counter
from pathlib import Path

import cv2

from omr.grid import GridError, read_sheet_auto
from tools.evaluate import EXPECTED


def main(folder, questions, options):
    totals, errors, silent_wrong, failures, lang_ok, reviews, times = Counter(), Counter(), 0, 0, 0, [], []
    files = sorted(Path(folder).glob("*.jpg"))
    for path in files:
        truth = json.loads(path.with_suffix(".json").read_text())
        start = time.perf_counter()
        try:
            result = read_sheet_auto(cv2.imread(str(path)), int(questions), int(options))
        except GridError as e:
            failures += 1
            print(f"{path.name}: FALHOU ({e})")
            continue
        times.append(time.perf_counter() - start)
        lang_ok += result["language"] == truth["language"]
        reviews.append(len(result["needs_review"]))
        for q in result["questions"]:
            t = truth["answers"][str(q["number"])]
            totals[t["kind"]] += 1
            if not EXPECTED[t["kind"]](t, q):
                errors[t["kind"]] += 1
                silent_wrong += q["status"] == "ok"
                print(f"  {path.name} Q{q['number']:>2} esperado {t['kind']} {t['marked']} → lido {q['status']} {q['answer']} {q['fills']}")

    n = len(files) - failures
    print(f"\nCartões: {len(files)} | lidos: {n} | falhas: {failures} | tempo médio {sum(times) / max(len(times), 1):.2f}s")
    print(f"Língua correta: {lang_ok}/{n}")
    for kind in ("ok", "blank", "multiple", "partial", "x"):
        if totals[kind]:
            print(f"  {kind:<9} {totals[kind]:>5} questões  acerto {100 * (1 - errors[kind] / totals[kind]):6.2f}%")
    total = sum(totals.values())
    if total:
        print(f"Geral: {100 * (1 - sum(errors.values()) / total):.2f}% | erradas sem pedir revisão: {silent_wrong}")
    print(f"Revisão por cartão: média {sum(reviews) / max(n, 1):.1f}")


if __name__ == "__main__":
    main(*sys.argv[1:])
