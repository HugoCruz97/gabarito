"""Serviço HTTP do leitor de cartões, chamado pelo Rails.

POST /read  (multipart)
  image=<foto>, questions=<nº de questões>, options=<alternativas por questão>,
  template=<modelo opcional, usado só como reserva>
  200 → { questions, language, needs_review, alignment, overlay_jpeg_base64 }
  422 → { error } quando a foto não pôde ser lida (ex.: não achou o cartão)

Padrão: leitura automática da grade (grid.py), que serve para qualquer variação do
cartão da escola e confere a estrutura (nº de questões) antes de aceitar a leitura.
O modelo fixo em PDF só entra se a leitura automática falhar E o simulado tiver
exatamente o formato do modelo.
"""
import base64
from functools import lru_cache
from pathlib import Path

import cv2
import numpy as np
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse

from .align import AlignmentError
from .grid import GridError, draw_auto, public, read_sheet_auto
from .reader import draw_result, read_sheet
from .template import build_template

TEMPLATES_DIR = Path(__file__).resolve().parent.parent / "templates"

app = FastAPI(title="Metaverso OMR")


@lru_cache(maxsize=8)
def load_template(name: str):
    path = TEMPLATES_DIR / f"{Path(name).name}.pdf"  # Path(name).name evita "../"
    if not path.exists():
        raise FileNotFoundError(name)
    return build_template(str(path))


def error(message: str, status: int = 422):
    return JSONResponse({"error": message}, status_code=status)


def encode(image: np.ndarray) -> str | None:
    ok, jpeg = cv2.imencode(".jpg", image, [cv2.IMWRITE_JPEG_QUALITY, 85])
    return base64.b64encode(jpeg.tobytes()).decode() if ok else None


@app.get("/health")
def health():
    return {"ok": True, "templates": sorted(p.stem for p in TEMPLATES_DIR.glob("*.pdf"))}


@app.post("/read")
async def read(
    image: UploadFile = File(...),
    questions: int = Form(...),
    options: int = Form(...),
    template: str | None = Form(None),
):
    if not (1 <= questions <= 200 and 2 <= options <= 5):
        return error("Quantidade de questões ou de alternativas inválida.", 400)

    photo = cv2.imdecode(np.frombuffer(await image.read(), dtype=np.uint8), cv2.IMREAD_COLOR)
    if photo is None:
        return error("Não consegui abrir a imagem. Envie uma foto em JPG ou PNG.")

    try:
        result = read_sheet_auto(photo, questions, options)
        overlay = draw_auto(result)
        response = public(result)
    except GridError as auto_error:
        response = read_with_template(photo, template, questions, options)
        if response is None:
            return error(f"{auto_error} Tente uma foto de cima, nítida, com o cartão inteiro aparecendo.")
        overlay = response.pop("_overlay")

    response["overlay_jpeg_base64"] = encode(overlay)
    return response


def read_with_template(photo, template, questions, options):
    """Reserva: só quando o simulado tem exatamente o formato do modelo fixo."""
    if not template:
        return None
    try:
        tpl = load_template(template)
    except FileNotFoundError:
        return None
    if len(tpl.questions) < questions or options != len(next(iter(tpl.questions.values()))):
        return None
    try:
        result = read_sheet(photo, tpl)
    except AlignmentError:
        return None
    result["_overlay"] = draw_result(result, tpl)
    result.pop("_warped")
    result["questions"] = [q for q in result["questions"] if q["number"] <= questions]
    result["needs_review"] = [n for n in result["needs_review"] if n <= questions]
    result["alignment"]["method"] = "modelo"
    return result
