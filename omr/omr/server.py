"""Serviço HTTP do leitor de cartões, chamado pelo Rails.

POST /read  (multipart: image=<foto>, template=<nome do modelo>)
  200 → { questions, language, needs_review, alignment, overlay_jpeg_base64 }
  422 → { error } quando a foto não pôde ser lida (ex.: não achou o cartão)
"""
import base64
from functools import lru_cache
from pathlib import Path

import cv2
import numpy as np
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse

from .align import AlignmentError
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


@app.get("/health")
def health():
    return {"ok": True, "templates": sorted(p.stem for p in TEMPLATES_DIR.glob("*.pdf"))}


@app.post("/read")
async def read(image: UploadFile = File(...), template: str = Form(...)):
    try:
        tpl = load_template(template)
    except FileNotFoundError:
        return error(f"Modelo de cartão '{template}' não encontrado no leitor.", 400)

    data = np.frombuffer(await image.read(), dtype=np.uint8)
    photo = cv2.imdecode(data, cv2.IMREAD_COLOR)
    if photo is None:
        return error("Não consegui abrir a imagem. Envie uma foto em JPG ou PNG.")

    try:
        result = read_sheet(photo, tpl)
    except AlignmentError as e:
        return error(f"{e} Tente uma foto mais nítida, com o cartão inteiro aparecendo.")

    overlay = draw_result(result, tpl)
    ok, jpeg = cv2.imencode(".jpg", overlay, [cv2.IMWRITE_JPEG_QUALITY, 85])
    result.pop("_warped")
    result["overlay_jpeg_base64"] = base64.b64encode(jpeg.tobytes()).decode() if ok else None
    return result
