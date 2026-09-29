# -*- coding: utf-8 -*-
"""강아지 마스코트 캐릭터 생성 서버.

emotion/photo.ipynb를 정리해서 옮긴 것. Stable Diffusion 1.5 + rembg로 견종/색상/성격
설명을 받아 배경이 지워진 강아지 캐릭터 PNG를 생성한다.

GPU가 필요해서 (Colab 등에서) 별도로 띄우고, mira 앱에서는
CharacterServerService가 이 서버의 베이스 URL을 가리키게 설정한다.
자세한 실행 방법은 README.md 참고.

## 사진 기반 생성은 포기했다
초기엔 사용자가 올린 실제 반려견 사진을 img2img 기준 이미지로 써서 "그 강아지를
닮은" 캐릭터를 만들려고 했지만, SD1.5는 이 용도로 학습된 모델이 아니라서 결과가
사진마다 들쭉날쭉했다 — strength를 조금만 올리면 형태가 깨지고, 낮추면 스타일 변환
없이 사진을 그대로 잘라붙인 것처럼 나왔다. 실제로 그 강아지를 닮게 하려면
dog_lora_colab.ipynb처럼 LoRA를 따로 학습시켜야 하는데, 이건 GPU로 몇십 분 걸리는
오프라인 작업이라 지금 구조엔 안 맞는다 (Backend/character-server/README.md 참고).

그래서 지금은 사진 업로드 여부와 무관하게 항상 `assets/dog/baby_idle.png`(기존
강아지방 캐릭터)를 img2img 기준 이미지로 쓰고, 품종/색상/성격은 텍스트로만 반영한다.
사진 업로드는 여전히 ai-server의 /analyze-pet-photo(품종·색상 텍스트 추출)에만
쓰인다 — 이 서버는 그 텍스트만 받는다.

원본 노트북의 한글 딕셔너리 키가 인코딩 손상으로 복구 불가능했어서
(BREED_MAP 등의 키) 같은 영어 프롬프트에 대응하는 한국어 표기를 새로 정리했다.
"""

import io
import os
import threading

from flask import Flask, request, send_file
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Frontend/mira/assets/dog/baby_idle.png — 기존 강아지방 캐릭터, img2img 기준 이미지.
_APP_DIR = os.path.dirname(os.path.abspath(__file__))
REFERENCE_IMAGE_PATH = os.environ.get("CHARACTER_REFERENCE_IMAGE") or os.path.normpath(
    os.path.join(_APP_DIR, "..", "..", "Frontend", "mira", "assets", "dog", "baby_idle.png")
)

# 실제 모델(파이프라인)은 첫 요청 전에 무겁게 로드되므로 지연 초기화한다.
# 이 모듈만 import해서 BREED_MAP 등을 테스트하거나 재사용할 수 있게 하기 위함.
_img2img_pipe = None
_bg_session = None
_ref_image = None
_lock = threading.Lock()
_inference_lock = threading.Lock()


def _get_pipeline():
    """(img2img 파이프라인, rembg 세션, 기준 이미지) 반환. 첫 호출 때만 무겁게 로드."""
    global _img2img_pipe, _bg_session, _ref_image
    if _ref_image is not None:
        return _img2img_pipe, _bg_session, _ref_image
    with _lock:
        if _ref_image is None:
            import torch
            from diffusers import (
                StableDiffusionPipeline,
                StableDiffusionImg2ImgPipeline,
                DPMSolverMultistepScheduler,
            )
            from rembg import new_session
            from PIL import Image

            base_pipe = StableDiffusionPipeline.from_pretrained(
                "runwayml/stable-diffusion-v1-5",
                torch_dtype=torch.float16,
                safety_checker=None,
            ).to("cuda")
            base_pipe.scheduler = DPMSolverMultistepScheduler.from_config(
                base_pipe.scheduler.config
            )
            _img2img_pipe = StableDiffusionImg2ImgPipeline(**base_pipe.components)
            _bg_session = new_session("u2net")

            ref_raw = Image.open(REFERENCE_IMAGE_PATH).convert("RGBA")
            white_bg = Image.new("RGBA", ref_raw.size, (255, 255, 255, 255))
            _ref_image = Image.alpha_composite(white_bg, ref_raw).convert("RGB").resize((512, 512))
    return _img2img_pipe, _bg_session, _ref_image


# 견종/색상/성격 한국어 표현 -> 영어 프롬프트 조각.
# 앱(PetSetup) 화면에서 자유 입력 또는 AI 사진 분석 결과(자유 문장)로 들어오기 때문에
# 정확히 일치하지 않을 수 있어 _lookup()에서 부분 일치까지 시도한다.
BREED_MAP = {
    # 소형견
    "포메라니안": "pomeranian",
    "말티즈": "maltese",
    "토이푸들": "toy poodle",
    "미니어처푸들": "miniature poodle",
    "푸들": "poodle",
    "비숑프리제": "bichon frise",
    "치와와": "chihuahua",
    "요크셔테리어": "yorkshire terrier",
    "시츄": "shih tzu",
    "페키니즈": "pekingese",
    "파피용": "papillon",
    "미니어처핀셔": "miniature pinscher",
    "미니핀": "miniature pinscher",
    "미니어처슈나우저": "miniature schnauzer",
    "재패니즈스피츠": "japanese spitz",
    "스피츠": "japanese spitz",
    "잭러셀테리어": "jack russell terrier",
    "이탈리안그레이하운드": "italian greyhound",
    "미니어처닥스훈트": "miniature dachshund",
    "닥스훈트": "dachshund",
    "라사압소": "lhasa apso",
    "티베탄테리어": "tibetan terrier",
    "폭스테리어": "fox terrier",
    "와이어폭스테리어": "wire fox terrier",
    "웨스트하이랜드화이트테리어": "west highland white terrier",
    "웨스티": "west highland white terrier",
    "스코티시테리어": "scottish terrier",
    "노퍽테리어": "norfolk terrier",
    "노리치테리어": "norwich terrier",
    "실키테리어": "silky terrier",
    "캐발리에킹찰스스패니얼": "cavalier king charles spaniel",
    "카발리에": "cavalier king charles spaniel",
    "차이니즈크레스티드": "chinese crested dog",
    "브뤼셀그리폰": "brussels griffon",
    "아펜핀셔": "affenpinscher",
    # 중형견
    "웰시코기": "corgi",
    "코카스파니엘": "cocker spaniel",
    "비글": "beagle",
    "프렌치불독": "french bulldog",
    "퍼그": "pug",
    "보스턴테리어": "boston terrier",
    "불독": "english bulldog",
    "시바견": "shiba inu",
    "바셋하운드": "basset hound",
    "잉글리시스프링거스패니얼": "english springer spaniel",
    "브리타니스패니얼": "brittany spaniel",
    "아메리칸에스키모독": "american eskimo dog",
    "아메리칸불리": "american bully",
    "스태퍼드셔불테리어": "staffordshire bull terrier",
    "에어데일테리어": "airedale terrier",
    "바센지": "basenji",
    "샤페이": "shar pei",
    "달마시안": "dalmatian",
    "휘핏": "whippet",
    "오스트레일리안캐틀독": "australian cattle dog",
    "켈피": "australian kelpie",
    # 인기 믹스/디자이너견
    "라브라두들": "labradoodle",
    "골든두들": "goldendoodle",
    "코카푸": "cockapoo",
    "말티푸": "maltipoo",
    "요크이푸": "yorkiepoo",
    # 한국 토종견
    "진돗개": "jindo dog",
    "삽살개": "sapsaree dog",
    "풍산개": "pungsan dog",
    # 대형견/사역견
    "골든리트리버": "golden retriever",
    "래브라도리트리버": "labrador retriever",
    "보더콜리": "border collie",
    "오스트레일리안셰퍼드": "australian shepherd",
    "셔틀랜드쉽독": "shetland sheepdog",
    "저먼셰퍼드": "german shepherd",
    "셰퍼드": "german shepherd",
    "시베리안허스키": "siberian husky",
    "허스키": "siberian husky",
    "사모예드": "samoyed",
    "알래스칸말라뮤트": "alaskan malamute",
    "로트와일러": "rottweiler",
    "도베르만": "doberman pinscher",
    "차우차우": "chow chow",
    "아키타견": "akita inu",
    "아키타": "akita inu",
    "그레이트데인": "great dane",
    "세인트버나드": "saint bernard",
    "버니즈마운틴독": "bernese mountain dog",
    "그레이하운드": "greyhound",
    "아프간하운드": "afghan hound",
    "살루키": "saluki",
    "로디지안리지백": "rhodesian ridgeback",
    "복서": "boxer",
    "불마스티프": "bullmastiff",
    "마스티프": "mastiff",
    "캐네인코르소": "cane corso",
    "프레사카나리오": "presa canario",
    "뉴펀들랜드": "newfoundland",
    "그레이트피레니즈": "great pyrenees",
    "아나톨리안셰퍼드": "anatolian shepherd",
    "올드잉글리시쉽독": "old english sheepdog",
    "브리아드": "briard",
    "콜리": "collie",
    "와이머라너": "weimaraner",
    "포인터": "pointer",
    "저먼포인터": "german shorthaired pointer",
    "잉글리시세터": "english setter",
    "아이리시세터": "irish setter",
    "고든세터": "gordon setter",
    # 믹스견 (품종 특징 없이 일반적인 강아지로 생성)
    "믹스견": "mixed breed",
    "믹스": "mixed breed",
    "잡종": "mixed breed",
}

COLOR_MAP = {
    # 흰색 계열
    "흰색": "white",
    "화이트": "white",
    "하얀": "white",
    "하양": "white",
    "새하얀": "white",
    "우유색": "white",
    "우윳빛": "white",
    "백구": "white",  # 진돗개 등에서 흰 털을 부르는 관용 표현
    # 검정 계열
    "검정": "black",
    "검은색": "black",
    "블랙": "black",
    "까만": "black",
    "까망": "black",
    "새까만": "black",
    "흑구": "black",
    # 갈색 계열
    "갈색": "brown",
    "브라운": "brown",
    "고동색": "brown",
    "밤색": "brown",
    "진갈색": "dark brown",
    "다크브라운": "dark brown",
    "초코색": "chocolate brown",
    "초콜릿색": "chocolate brown",
    "카라멜색": "caramel brown",
    # 크림/베이지/아이보리 계열
    "크림": "cream beige",
    "크림색": "cream beige",
    "베이지": "cream beige",
    "아이보리": "ivory cream",
    "옅은 갈색": "light tan",
    "연갈색": "light tan",
    "살구색": "apricot",
    "애프리콧": "apricot",
    # 회색/은색 계열
    "회색": "gray",
    "그레이": "gray",
    "잿빛": "gray",
    "은색": "silver gray",
    "은회색": "silver gray",
    "실버": "silver gray",
    # 황금색/노란 계열
    "황금색": "golden",
    "골든": "golden",
    "금색": "golden",
    "노란": "golden yellow",
    "노랑": "golden yellow",
    "황토색": "golden brown",
    "황갈색": "golden brown",
    # 붉은/탄색 계열 (진돗개·시바견의 "황구" 같은 관용 표현 포함)
    "빨간": "red",
    "빨강": "red",
    "붉은색": "red",
    "적갈색": "reddish brown",
    "탄색": "tan",
    "황구": "reddish tan",
    "주황색": "orange",
    "오렌지색": "orange",
    # 파란/청회색 계열
    "블루그레이": "blue gray",
    "청회색": "blue gray",
    "스틸블루": "steel blue",
    "스모크색": "smoke gray",
    "진회색": "dark gray",
    "연회색": "light gray",
    "밝은갈색": "light brown",
    # 두 가지 색 섞임 / 무늬
    "흑백": "black and white",
    "갈색+흰색": "brown and white",
    "삼색": "tricolor",
    "트라이컬러": "tricolor",
    "점박이": "spotted",
    "얼룩무늬": "spotted",
    "얼룩": "spotted",
    "브린들": "brindle",
    "블루멀": "blue merle",
    "멀": "merle",
    "파티컬러": "parti-color",
    "세이블": "sable",
}

# 앱의 PetSetup 화면에서 실제로 쓰는 성격 칩(활발함/애교쟁이/호기심/차분함)과
# photo.ipynb 원본에 있던 나머지 표현을 함께 지원한다.
PERSONALITY_MAP = {
    "활발함": "energetic pose, big happy smile, excited expression",
    "차분함": "calm sitting pose, gentle smile, peaceful expression",
    "장난꾸러기": "playful pose, mischievous grin, tilted head",
    "애교쟁이": "adorable pose, sparkling big eyes, sweet smile",
    "애교많음": "adorable pose, sparkling big eyes, sweet smile",
    "호기심": "curious pose, head tilted, sparkling curious eyes",
    "당당함": "confident standing pose, proud expression, head up",
    "수줍음": "shy pose, small smile, looking up cutely",
}

DEFAULT_BREED = "포메라니안"
DEFAULT_COLOR = "흰색"
DEFAULT_PERSONALITY = "활발함"

# baby_idle.png를 기준으로 시작해서 텍스트로 품종/색상/성격만 바꾸는 img2img 강도.
# 0.68+ : 형태가 쉽게 깨짐 (색 이상해지거나 기형으로 나옴)
# 0.5 이하: 원본(흰 포메라니안)에서 거의 안 벗어남
# 0.6이 여러 견종으로 테스트했을 때 가장 안정적이었다 - 다만 strength만으로는 색상/견종이
# 아예 안 바뀔 때가 있어서(원본이 흰 포메라니안이라 그쪽으로 계속 끌림), GUIDANCE_SCALE로
# 텍스트 프롬프트 반영 강도를 별도로 더 올려서 보완한다.
IMG2IMG_STRENGTH = 0.6

# 텍스트 프롬프트를 얼마나 강하게 따를지 (strength와는 별개 축). 기본값 7.5는 색상/견종이
# 원본(흰 포메라니안) 쪽으로 계속 끌리는 경우가 있어서 더 올렸다 - strength를 올리는 것과
# 달리 형태가 깨지는 부작용 없이 프롬프트 반영을 강화하는 쪽이라 우선 이걸로 시도한다.
GUIDANCE_SCALE = 11.0


def _lookup(value: str, table: dict, default_key: str) -> str:
    """정확히 일치하면 그대로, 아니면 테이블 키가 value에 포함되는지 부분 일치로 찾는다.
    (AI 사진 분석 결과는 "말티즈로 추정돼요" 같은 완전한 문장일 수 있어서)
    둘 다 실패하면 기본값으로 대체한다 — SD1.5는 한국어 프롬프트를 이해하지 못한다.

    부분 일치는 긴 키부터 검사한다 — 예를 들어 "황갈색"이 "갈색"의 상위 문자열이라
    "갈색"을 먼저 검사하면 "황갈색"을 입력해도 항상 "갈색"으로만 걸려버린다.

    부분 일치 검사 전에 공백을 모두 제거한다 — "시베리안 허스키"처럼 외래어 견종명은
    띄어쓰기가 사람마다 달라서, 공백을 그대로 두면 "시베리안허스키" 키가 있어도
    못 찾는 경우가 많다.
    """
    value = (value or "").strip()
    if value in table:
        return table[value]
    compact_value = "".join(value.split())
    for key in sorted(table, key=len, reverse=True):
        if "".join(key.split()) in compact_value:
            return table[key]
    return table[default_key]


def build_prompt(breed_kr: str, color_kr: str, personality_kr: str) -> tuple[str, str]:
    breed = _lookup(breed_kr, BREED_MAP, DEFAULT_BREED)
    color = _lookup(color_kr, COLOR_MAP, DEFAULT_COLOR)
    personality = _lookup(personality_kr, PERSONALITY_MAP, DEFAULT_PERSONALITY)

    # Frontend/mira/assets/dog/*.png(기존 강아지방 캐릭터)와 스타일을 맞춘다 — 부드러운
    # 카툰풍 일러스트(굵은 테두리의 플랫 벡터도, 실사 3D 렌더도 아님). img2img 기준
    # 이미지(baby_idle.png)와 함께 써야 이 스타일이 안정적으로 나온다 (build_prompt만
    # txt2img로 단독으로 쓰면 결과가 매번 크게 달라진다).
    prompt = (
        f"full body chibi {color} {breed} puppy standing on four legs, "
        "kawaii mascot illustration, flat vector art, cel shading, clean bold black outline, "
        "big round glossy black eyes with white sparkle highlight, blush pink cheeks, "
        "smiling open mouth, soft round chubby body, fluffy fur, "
        f"{personality}, "
        "isolated on plain white background, no border, no frame, no shadow"
    )
    negative_prompt = (
        "badge, circular frame, decorative border, polka dot, vignette, "
        "colorful background, pattern background, sticker border, frame, "
        "cropped, close up, head only, face only, portrait, no body, "
        "3d render, photorealistic, realistic photo, photograph, detailed realistic fur, "
        "sketch, pencil sketch, rough sketch, watercolor, painterly, gradient shading, "
        "soft blurry outline, textured brush strokes, "
        "bear, teddy bear, cat, feline, whiskers, "
        "collar, tag, accessories, "
        "humanoid, ground, multiple animals, "
        "text, watermark, logo, deformed, extra limbs, blurry, low quality, ugly"
    )
    return prompt, negative_prompt


@app.get("/health")
def health():
    return {"status": "ok"}


@app.route("/generate", methods=["POST"])
def generate():
    import torch
    from rembg import remove

    breed_kr = request.form.get("breed", DEFAULT_BREED)
    color_kr = request.form.get("color", DEFAULT_COLOR)
    personality_kr = request.form.get("personality", DEFAULT_PERSONALITY)
    try:
        seed = int(request.form.get("seed", 42))
        if not 0 <= seed < 2**32:
            raise ValueError("invalid seed")
    except ValueError:
        return {"error": "invalid seed"}, 400

    prompt, negative_prompt = build_prompt(breed_kr, color_kr, personality_kr)

    img2img_pipe, bg_session, ref_image = _get_pipeline()
    generator = torch.Generator(device="cuda").manual_seed(seed)
    with _inference_lock:
        img = img2img_pipe(
            prompt=prompt,
            negative_prompt=negative_prompt,
            image=ref_image,
            strength=IMG2IMG_STRENGTH,
            guidance_scale=GUIDANCE_SCALE,
            generator=generator,
        ).images[0]

    final = remove(img, session=bg_session)

    buf = io.BytesIO()
    final.save(buf, format="PNG")
    buf.seek(0)
    return send_file(buf, mimetype="image/png")


def _build_motions(preview_bytes, traits):
    import torch
    from PIL import Image
    from rembg import remove
    from motion_generation import build_character

    pipe, bg_session, _ = _get_pipeline()
    breed = _lookup(traits['breed'], BREED_MAP, DEFAULT_BREED)
    color = _lookup(traits['color'], COLOR_MAP, DEFAULT_COLOR)
    _, negative = build_prompt(traits['breed'], traits['color'], traits['personality'])

    def generate_pose(reference, pose):
        white = Image.new('RGBA', reference.size, 'white')
        source = Image.alpha_composite(white, reference).convert('RGB').resize((512, 512))
        prompt = (
            f'the same {color} {breed} puppy as the reference image, {pose}, '
            'full body chibi dog, preserve identical face, ears, fur markings and colors, '
            'kawaii mascot illustration, flat vector art, cel shading, bold black outline, '
            'soft round body, isolated on plain white background, no shadow, no props'
        )
        with _inference_lock, torch.inference_mode():
            result = pipe(prompt=prompt, negative_prompt=negative, image=source,
                          strength=0.58, guidance_scale=9.0, num_inference_steps=30,
                          generator=torch.Generator(device='cuda').manual_seed(traits['seed'])).images[0]
        return remove(result, session=bg_session).convert('RGBA')

    return build_character(preview_bytes, generate_pose)


from motion_jobs import register_motion_routes
register_motion_routes(app, _build_motions)


if __name__ == "__main__":
    # 로컬/Colab에서 직접 실행할 때. 배포 환경에서는 gunicorn 등을 쓰는 걸 권장.
    app.run(host="0.0.0.0", port=5000)
