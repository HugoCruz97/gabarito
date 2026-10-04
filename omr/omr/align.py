"""Alinha a foto do cartão ao modelo em branco.

O cartão não tem marcadores de canto, mas tem muito desenho fixo (logo, títulos,
instruções, números das questões). Usamos esses pontos de referência:
1. ORB + RANSAC: acha centenas de pontos em comum entre foto e modelo e calcula a
   homografia (corrige perspectiva, rotação e escala de uma vez);
2. ECC: refinamento fino, sub-pixel, só na área das respostas.
"""
import cv2
import numpy as np

MAX_SIDE = 2200


class AlignmentError(Exception):
    pass


def normalize_lighting(gray: np.ndarray) -> np.ndarray:
    """Remove sombras e iluminação irregular dividindo pelo 'fundo' estimado."""
    background = cv2.morphologyEx(gray, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (31, 31)))
    background = cv2.GaussianBlur(background, (0, 0), 15)
    norm = cv2.divide(gray, background, scale=255)
    return norm


def to_gray(image: np.ndarray) -> np.ndarray:
    if image.ndim == 2:
        return image
    # Canal "mínimo": caneta azul fica tão escura quanto a preta (o vermelho do azul é baixo)
    return image.min(axis=2)


def align(photo: np.ndarray, template_gray: np.ndarray, answer_box: tuple[int, int, int, int] | None = None):
    """Retorna (foto alinhada em cinza no tamanho do modelo, info)."""
    gray = to_gray(photo)
    scale = MAX_SIDE / max(gray.shape)
    if scale < 1:
        gray = cv2.resize(gray, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)

    orb = cv2.ORB_create(nfeatures=8000, scaleFactor=1.2, nlevels=10)
    tpl = normalize_lighting(template_gray)
    img = normalize_lighting(gray)
    kp1, des1 = orb.detectAndCompute(tpl, None)
    kp2, des2 = orb.detectAndCompute(img, None)
    if des2 is None or len(kp2) < 50:
        raise AlignmentError("Não encontrei o cartão na imagem.")

    matcher = cv2.BFMatcher(cv2.NORM_HAMMING)
    pairs = matcher.knnMatch(des2, des1, k=2)
    good = [m for m, n in (p for p in pairs if len(p) == 2) if m.distance < 0.75 * n.distance]
    if len(good) < 30:
        raise AlignmentError(f"Poucos pontos em comum com o modelo ({len(good)}). Foto muito borrada ou de outro cartão?")

    src = np.float32([kp2[m.queryIdx].pt for m in good])
    dst = np.float32([kp1[m.trainIdx].pt for m in good])
    H, inliers = cv2.findHomography(src, dst, cv2.RANSAC, 4.0, maxIters=5000, confidence=0.999)
    if H is None:
        raise AlignmentError("Não consegui alinhar a foto ao modelo.")
    inlier_count = int(inliers.sum())
    if inlier_count < 25:
        raise AlignmentError(f"Alinhamento pouco confiável ({inlier_count} pontos).")

    h, w = template_gray.shape
    warped = cv2.warpPerspective(gray, H, (w, h), flags=cv2.INTER_LINEAR, borderValue=255)

    ecc = None
    if answer_box:
        x0, y0, x1, y1 = answer_box
        try:
            warp = np.eye(3, dtype=np.float32)
            criteria = (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 60, 1e-5)
            a = cv2.GaussianBlur(normalize_lighting(template_gray)[y0:y1, x0:x1], (5, 5), 0).astype(np.float32)
            b = cv2.GaussianBlur(normalize_lighting(warped)[y0:y1, x0:x1], (5, 5), 0).astype(np.float32)
            ecc, warp = cv2.findTransformECC(a, b, warp, cv2.MOTION_HOMOGRAPHY, criteria, None, 5)
            # aplica a correção (definida no recorte) na imagem inteira
            T = np.array([[1, 0, x0], [0, 1, y0], [0, 0, 1]], np.float32)
            full = T @ warp @ np.linalg.inv(T)
            warped = cv2.warpPerspective(warped, full, (w, h), flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP, borderValue=255)
        except cv2.error:
            ecc = None  # sem refinamento; o ORB costuma bastar

    return warped, {"matches": len(good), "inliers": inlier_count, "ecc": None if ecc is None else round(float(ecc), 3)}
