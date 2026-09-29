"""Build aligned, transparent clips from the user's exact generated character.

Diffusion creates key poses, not unrelated images for every video frame. Dense
flow interpolates transitions; small deformations animate breathing/chewing.
No GPU work is performed at import time, so packaging can be tested on CPU.
"""
import base64
import io
import math

import numpy as np
from PIL import Image

SIZE = 256
FPS = 12
POSES = {
    "walk_a": "walking toward the right, left front paw and right rear paw stepping forward, side view",
    "walk_b": "walking toward the right, right front paw and left rear paw stepping forward, side view",
    "feed": "side view facing right, standing with paws planted, neck bent down, muzzle near the floor, eating, no bowl",
    "wash": "side view facing right, sitting upright, eyes gently closed, ready for a bath, no bathtub",
    "play": "side view facing right, playful bow, front legs lowered and hindquarters raised, no ball",
    "sleep": "side view facing right, lying down curled up sleeping, eyes closed, head resting on front paws, no bed",
}


def png(image):
    buffer = io.BytesIO()
    # The room draws at 140px. Indexed RGBA keeps the alpha channel while making
    # a full set small enough for the app's web/local preferences cache.
    image.quantize(colors=256, method=Image.Quantize.FASTOCTREE,
                   dither=Image.Dither.NONE).save(buffer, format="PNG", optimize=True)
    return base64.b64encode(buffer.getvalue()).decode("ascii")


def aligned(image):
    """Identical canvas and foot baseline prevent position jumps between poses."""
    image = image.convert("RGBA")
    bbox = image.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    if bbox is None:
        raise ValueError("Empty character cutout")
    crop = image.crop(bbox)
    scale = min(224 / crop.width, 218 / crop.height)
    crop = crop.resize((max(1, round(crop.width * scale)), max(1, round(crop.height * scale))), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE))
    canvas.alpha_composite(crop, ((SIZE - crop.width) // 2, 240 - crop.height))
    return canvas


def _premultiplied(image):
    pixels = np.asarray(image, dtype=np.float32) / 255
    pixels[..., :3] *= pixels[..., 3:4]
    return pixels


def _image(pixels):
    alpha = np.clip(pixels[..., 3:4], 0, 1)
    rgb = np.divide(pixels[..., :3], alpha, out=np.zeros_like(pixels[..., :3]), where=alpha > .001)
    return Image.fromarray(np.uint8(np.clip(np.concatenate([rgb, alpha], axis=2), 0, 1) * 255))


def transition(start, end, count=8):
    """Bidirectional optical-flow morph with exact endpoint frames."""
    import cv2
    a, b = _premultiplied(start), _premultiplied(end)
    def gray(p):
        # Composite over white for flow; interpolate premultiplied RGBA below.
        rgb = np.uint8(np.clip(p[..., :3] + 1 - p[..., 3:4], 0, 1) * 255)
        return cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    ag, bg = gray(a), gray(b)
    ab = cv2.calcOpticalFlowFarneback(ag, bg, None, .5, 4, 25, 5, 7, 1.5, 0)
    ba = cv2.calcOpticalFlowFarneback(bg, ag, None, .5, 4, 25, 5, 7, 1.5, 0)
    y, x = np.mgrid[:SIZE, :SIZE].astype(np.float32)
    frames = [start]
    for index in range(1, count - 1):
        t = index / (count - 1)
        t = t * t * (3 - 2 * t)
        left = cv2.remap(a, x - ab[..., 0] * t, y - ab[..., 1] * t, cv2.INTER_LINEAR)
        right = cv2.remap(b, x - ba[..., 0] * (1 - t), y - ba[..., 1] * (1 - t), cv2.INTER_LINEAR)
        frames.append(_image(left * (1 - t) + right * t))
    return frames + [end]


def cycle(pose, kind, count=16):
    """Loop smoothly while keeping the same face, coat and planted paws."""
    import cv2
    pixels = _premultiplied(pose)
    y, x = np.mgrid[:SIZE, :SIZE].astype(np.float32)
    upper = np.clip((240 - y) / 150, 0, 1)
    head = np.clip((x - 110) / 100, 0, 1) * upper
    frames = []
    for i in range(count):
        wave = math.sin(2 * math.pi * i / count)
        dx, dy = np.zeros_like(x), np.zeros_like(y)
        if kind == "feed":
            dy = head * wave * 3
        elif kind == "wash":
            dx = upper * wave * 3
        elif kind == "play":
            dy = upper * wave * 5
        elif kind == "greet":
            dx = upper * wave * 2
            dy = upper * wave * 2
        else:
            dy = upper * wave * (1.2 if kind == "sleep" else 1.6)
        frames.append(_image(cv2.remap(pixels, x + dx, y + dy, cv2.INTER_LINEAR)))
    frames[0] = pose
    return frames


def build_character(preview_bytes, generate_pose):
    """generate_pose(reference RGBA, pose instruction) is supplied by the GPU server."""
    reference = Image.open(io.BytesIO(preview_bytes)).convert("RGBA")
    idle = aligned(reference)
    poses = {name: aligned(generate_pose(reference, prompt)) for name, prompt in POSES.items()}
    clips = {}
    def add(name, frames, loop):
        clips[name] = {"fps": FPS, "loop": loop, "frames": [png(frame) for frame in frames]}
    add("idle", cycle(idle, "idle"), True)
    add("greet", cycle(idle, "greet"), True)
    # Start at idle so movement begins without a pose jump.
    walk = []
    for a, b in [(idle, poses['walk_a']), (poses['walk_a'], idle),
                 (idle, poses['walk_b']), (poses['walk_b'], idle)]:
        walk.extend(transition(a, b, 4)[:-1])
    add("walk", walk, True)
    for action in ("feed", "wash", "play", "sleep"):
        entry = transition(idle, poses[action])
        add(action + "_enter", entry, False)
        add(action, cycle(poses[action], action), True)
        add(action + "_exit", list(reversed(entry)), False)
    return {"version": 1, "preview": base64.b64encode(preview_bytes).decode("ascii"), "clips": clips}
