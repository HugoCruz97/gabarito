"""Lê um cartão-resposta e imprime o resultado em JSON.

Uso: python -m omr templates/cartao.pdf foto.jpg [conferencia.jpg]
"""
import json
import sys

import cv2

from .align import AlignmentError
from .reader import draw_result, read_sheet
from .template import build_template


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    template = build_template(argv[0])
    image = cv2.imread(argv[1])
    if image is None:
        print(json.dumps({"error": f"Não consegui abrir a imagem {argv[1]}"}, ensure_ascii=False))
        return 1
    try:
        result = read_sheet(image, template)
    except AlignmentError as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        return 1
    if len(argv) > 2:
        cv2.imwrite(argv[2], draw_result(result, template))
    result.pop("_warped")
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
