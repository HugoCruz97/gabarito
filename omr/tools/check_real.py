"""Confere a leitura automática de uma foto real contra o gabarito informado à mão.

Uso: python -m tools.check_real foto.jpg "CDBCCDCBAABBDAABBCBABBCBC" A-D espanhol
"""
import sys

import cv2

from omr.grid import draw_auto, read_sheet_auto


def main(path, expected, options, language=None):
    k = len(options.replace("-", "")) if "-" not in options else "ABCDE".index(options[-1]) + 1
    result = read_sheet_auto(cv2.imread(path), len(expected), k)
    cv2.imwrite(path.rsplit(".", 1)[0] + "_conferencia.jpg", draw_auto(result))

    wrong = []
    for q, exp in zip(result["questions"], expected):
        if q["answer"] != exp or q["status"] != "ok":
            wrong.append(f"Q{q['number']}: esperado {exp}, lido {q['answer']} ({q['status']}) {q['fills']}")
    print(f"alinhamento: {result['alignment']}")
    print(f"língua: lida={result['language']} esperada={language}")
    print(f"acertos: {len(expected) - len(wrong)}/{len(expected)}")
    print("\n".join(wrong))


if __name__ == "__main__":
    main(*sys.argv[1:])
