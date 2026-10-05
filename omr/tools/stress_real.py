"""Gera variações de uma foto real (rotação, perspectiva, sombra, desfoque, JPEG) e confere
a leitura de cada uma contra o gabarito informado.

Uso: python -m tools.stress_real foto.jpg "CDBCCDCBAABBDAABBCBABBCBC" 4 espanhol 20
"""
import random
import sys

import cv2

from omr.grid import GridError, read_sheet_auto
from tools.synth import photograph


def main(path, expected, options, language, count=20):
    base = cv2.imread(path)
    rng = random.Random(1)
    ok_cards, total_wrong, total_review, failures = 0, 0, 0, 0
    for i in range(int(count)):
        severity = 0.5 + i / int(count)  # de leve a forte
        photo = photograph(base, rng, severity)
        try:
            result = read_sheet_auto(photo, len(expected), int(options))
        except GridError as e:
            failures += 1
            print(f"variação {i:02d} (intensidade {severity:.2f}): FALHOU — {e}")
            continue
        wrong = [q["number"] for q, exp in zip(result["questions"], expected) if q["answer"] != exp and q["status"] == "ok"]
        review = [q["number"] for q, exp in zip(result["questions"], expected) if q["status"] != "ok"]
        lang = "ok" if result["language"] == language else f"lida={result['language']}"
        total_wrong += len(wrong)
        total_review += len(review)
        ok_cards += not wrong and not review
        print(f"variação {i:02d} (intensidade {severity:.2f}): {result['alignment']['method']:<16} "
              f"erradas sem revisão={wrong or '-'} revisar={review or '-'} língua {lang}")
    print(f"\n{int(count)} variações | perfeitas: {ok_cards} | falhas de leitura: {failures} | "
          f"erradas sem pedir revisão: {total_wrong} | questões para revisar: {total_review}")


if __name__ == "__main__":
    main(*sys.argv[1:])
