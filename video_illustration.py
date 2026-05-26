"""
Video Illustration Style Transfer
Style encre + aquarelle + fond doré ornemental — proche d'une illustration
peinte à la main telle que la référence fournie.
"""

import cv2
import numpy as np
import os
import subprocess
import shutil

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
VIDEO_INPUT  = r"C:\Users\amine\AppData\Local\Packages\5319275A.WhatsAppDesktop_cv1g1gvanyjgm\LocalState\sessions\9C4D7DA4E39E4E47BC527B45A77E95D6CA72C213\transfers\2026-21\WhatsApp Video 2026-05-24 at 6.30.24 PM.mp4"
VIDEO_OUTPUT = r"F:\Projets\PFE-IoT-Security-TT\video_illustre.mp4"

BACKGROUND_IMAGE = ""

# ─── RÉGLAGES EFFET ──────────────────────────────────────────────────────────
# cv2.stylization : aquarelle / peinture
STYLE_SIGMA_S     = 150    # taille voisinage (60-200) — + grand = + lisse
STYLE_SIGMA_R     = 0.35   # tolérance couleur (0.0-1.0) — + grand = + aplats

# cv2.pencilSketch : traits d'encre fins
SKETCH_SIGMA_S    = 60     # détail des traits (10-200)
SKETCH_SIGMA_R    = 0.07   # seuil couleur (0.0-1.0)
SKETCH_SHADE      = 0.04   # opacité des hachures (0.0-0.1)
SKETCH_BLEND      = 0.60   # force du mélange traits/couleur (0=aucun, 1=fort)

# Couleurs
SATURATION_BOOST  = 2.2    # éclat des couleurs
WARM_RED_BOOST    = 1.20   # boost rouge/rose
WARM_BLUE_CUT     = 0.80   # réduction bleu
VIGNETTE_STRENGTH = 0.45   # vignetage bords

# Masque fond — ellipse très douce, fond visible naturellement sur les côtés
MASK_W_RATIO  = 0.62
MASK_H_RATIO  = 0.86
MASK_CY_RATIO = 0.50
MASK_BLUR     = 151
BG_BLUR_SIZE  = 15
# ──────────────────────────────────────────────────────────────────────────────


# ── Pré-calculs globaux ───────────────────────────────────────────────────────
_vignette_cache: dict = {}
_mask_cache:     dict = {}


def build_vignette(h, w):
    key = (h, w)
    if key not in _vignette_cache:
        cx, cy = w / 2, h / 2
        Y, X = np.ogrid[:h, :w]
        dist = np.sqrt(((X - cx) / cx) ** 2 + ((Y - cy) / cy) ** 2)
        vig = 1.0 - np.clip(dist * VIGNETTE_STRENGTH, 0, 1)
        _vignette_cache[key] = np.stack([vig] * 3, axis=-1).astype(np.float32)
    return _vignette_cache[key]


def build_person_mask(h, w):
    key = (h, w)
    if key not in _mask_cache:
        mask = np.zeros((h, w), np.uint8)
        cx = w // 2
        cy = int(h * MASK_CY_RATIO)
        axes = (int(w * MASK_W_RATIO / 2), int(h * MASK_H_RATIO / 2))
        cv2.ellipse(mask, (cx, cy), axes, 0, 0, 360, 255, -1)
        blur_k = MASK_BLUR if MASK_BLUR % 2 == 1 else MASK_BLUR + 1
        mask = cv2.GaussianBlur(mask, (blur_k, blur_k), 0)
        # Limiter l'alpha max à 0.88 : le fond transparaît légèrement partout
        alpha = mask.astype(np.float32) / 255.0 * 0.88
        _mask_cache[key] = np.stack([alpha] * 3, axis=-1)
    return _mask_cache[key]


# ── Pipeline illustration ────────────────────────────────────────────────────
def stylize(frame):
    """
    cv2.stylization = effet aquarelle/peinture (fond de couleur lissé).
    cv2.pencilSketch = traits d'encre fins par-dessus.
    Mélange multiplicatif → illustration peinte + dessinée.
    """
    # Aquarelle
    painted = cv2.stylization(frame, sigma_s=STYLE_SIGMA_S, sigma_r=STYLE_SIGMA_R)

    # Traits crayon/encre (gray_sketch = niveaux de gris, range 0-255)
    gray_sketch, _ = cv2.pencilSketch(
        frame,
        sigma_s=SKETCH_SIGMA_S,
        sigma_r=SKETCH_SIGMA_R,
        shade_factor=SKETCH_SHADE
    )

    # Convertir sketch en masque multiplicatif (255 = pas de trait, 0 = trait noir)
    lines = cv2.cvtColor(gray_sketch, cv2.COLOR_GRAY2BGR).astype(np.float32) / 255.0
    # Mélange : SKETCH_BLEND=0 → pure aquarelle, 1 → traits dominants
    blend_lines = 1.0 - SKETCH_BLEND * (1.0 - lines)
    result = np.clip(painted.astype(np.float32) * blend_lines, 0, 255).astype(np.uint8)
    return result


def grade_colors(frame):
    """Boost saturation + virage chaud magenta/rose comme dans l'illustration."""
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV).astype(np.float32)
    hsv[:, :, 1] = np.clip(hsv[:, :, 1] * SATURATION_BOOST, 0, 255)
    hsv[:, :, 2] = np.clip(hsv[:, :, 2] * 1.05, 0, 255)
    result = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR).astype(np.float32)
    result[:, :, 0] = np.clip(result[:, :, 0] * WARM_BLUE_CUT,  0, 255)
    result[:, :, 2] = np.clip(result[:, :, 2] * WARM_RED_BOOST, 0, 255)
    return result.astype(np.uint8)


# ── Pipeline complet par frame ────────────────────────────────────────────────
def illustrate_frame(frame, bg_resized, alpha3, vignette3):
    # 1. Stylisation aquarelle + traits d'encre
    result = stylize(frame)

    # 2. Grading couleurs chauds
    result = grade_colors(result)

    # 3. Fond doré (si fourni)
    if bg_resized is not None:
        result = (result.astype(np.float32) * alpha3 +
                  bg_resized.astype(np.float32) * (1.0 - alpha3)).astype(np.uint8)

    # 4. Vignetage
    result = np.clip(result.astype(np.float32) * vignette3, 0, 255).astype(np.uint8)

    return result


# ── Fusion audio ─────────────────────────────────────────────────────────────
def find_ffmpeg():
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg:
        return ffmpeg
    common = [
        r"C:\ffmpeg\bin\ffmpeg.exe",
        r"C:\Program Files\ffmpeg\bin\ffmpeg.exe",
        os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-7.1-full_build\bin\ffmpeg.exe"),
    ]
    for p in common:
        if os.path.isfile(p):
            return p
    return None


def merge_audio(video_no_audio, source_video, output_path):
    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        shutil.move(video_no_audio, output_path)
        print("[INFO] ffmpeg non trouvé — vidéo sauvegardée sans audio.")
        print("       Installez ffmpeg et relancez pour avoir l'audio.")
        return
    cmd = [
        ffmpeg, "-y",
        "-i", video_no_audio,
        "-i", source_video,
        "-c:v", "copy",
        "-c:a", "aac",
        "-map", "0:v:0",
        "-map", "1:a:0",
        "-shortest",
        output_path
    ]
    result = subprocess.run(cmd, capture_output=True)
    if result.returncode == 0:
        os.remove(video_no_audio)
        print(f"Audio fusionné → {output_path}")
    else:
        shutil.move(video_no_audio, output_path)
        print(f"[AVERT] Fusion audio échouée.\n{result.stderr.decode(errors='ignore')[-400:]}")


# ── Entrée principale ─────────────────────────────────────────────────────────
def process_video():
    cap = cv2.VideoCapture(VIDEO_INPUT)
    if not cap.isOpened():
        print(f"[ERREUR] Impossible d'ouvrir : {VIDEO_INPUT}")
        return

    fps    = cap.get(cv2.CAP_PROP_FPS) or 30.0
    width  = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total  = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    print(f"Vidéo : {width}x{height} @ {fps:.1f}fps — {total} frames ({total/fps:.1f}s)")

    # Fond doré
    bg_resized = None
    alpha3 = None
    if BACKGROUND_IMAGE and os.path.exists(BACKGROUND_IMAGE):
        bg = cv2.imread(BACKGROUND_IMAGE)
        bg_resized = cv2.resize(bg, (width, height))
        # Flou de profondeur : le fond semble derrière la personne
        if BG_BLUR_SIZE > 1:
            k = BG_BLUR_SIZE if BG_BLUR_SIZE % 2 == 1 else BG_BLUR_SIZE + 1
            bg_resized = cv2.GaussianBlur(bg_resized, (k, k), 0)
        alpha3 = build_person_mask(height, width)
        print(f"Fond chargé : {BACKGROUND_IMAGE}")
    elif BACKGROUND_IMAGE:
        print(f"[AVERT] Fond introuvable : {BACKGROUND_IMAGE}")

    vignette3 = build_vignette(height, width)

    tmp_output = VIDEO_OUTPUT.replace(".mp4", "_noaudio.mp4")
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(tmp_output, fourcc, fps, (width, height))
    if not out.isOpened():
        print("[ERREUR] Impossible de créer le fichier de sortie.")
        cap.release()
        return

    print("Traitement en cours (style illustration encre+aquarelle)...")
    for i in range(total):
        ret, frame = cap.read()
        if not ret:
            break

        result = illustrate_frame(frame, bg_resized, alpha3, vignette3)
        out.write(result)

        pct  = (i + 1) / total * 100
        done = int(pct / 2)
        bar  = "#" * done + "-" * (50 - done)
        print(f"\r[{bar}] {pct:.0f}% ({i+1}/{total})", end="", flush=True)

    cap.release()
    out.release()
    print("\n\nRendu terminé. Fusion audio...")
    merge_audio(tmp_output, VIDEO_INPUT, VIDEO_OUTPUT)
    print(f"Vidéo finale : {VIDEO_OUTPUT}")


if __name__ == "__main__":
    process_video()
