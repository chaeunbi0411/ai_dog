# character-server

`emotion/photo.ipynb`를 옮긴 강아지 마스코트 캐릭터 생성 서버 (Stable Diffusion 1.5 + rembg).
GPU가 필요해서 `ai-server`(FastAPI, CPU로 충분)와 분리했다.

## 생성 캐릭터의 홈 화면 동작

- 기본값은 기존 `assets/dog/` 강아지다. 생성하지 않거나 실패하면 기존 캐릭터를 유지한다.
- `/generate`는 기존처럼 기본 PNG **한 장만** 반환한다. 앱은 이 이미지만 미리보기로 보여준다.
- 앱이 이 PNG를 `POST /motion-jobs`에 보내면 서버는 같은 이미지를 기준으로 걷기·식사·목욕·놀기·수면 자세를 생성한다. 프레임은 미리보기에 표시하지 않는다.
- `GET /motion-jobs/<id>`의 상태는 `queued`, `running`, `ready`, `failed`다. `ready` 응답의 `character`에 PNG Base64 프레임, fps, 반복 여부가 들어 있다.
- 전체 세트가 완성되고 사용자가 저장했을 때만 홈 캐릭터를 교체한다. 앱은 가족 ID별로 기기에 저장한다. 다른 가족의 기기까지 파일을 공유하는 업로드/동기화 기능은 포함하지 않는다.
- 밥·목욕·놀기·재우기는 이동 → 준비 자세 → 반복 동작 → 마무리 자세 → 원래 위치 복귀 순서다. 말풍선도 각 단계에 맞추며 보상과 돌봄 완료 기록은 복귀 후 처리한다.
- 생성 캐릭터는 레벨이 올라가도 같은 외형을 유지한다. 기존 기본 캐릭터의 성장별 이미지는 그대로 사용한다.

### 현재 Colab 서버에 적용

기존 `photo.ipynb`/`FINAL.ipynb`의 서버 셀만 실행하면 새 `/motion-jobs` API가 없다.
**앱 변경만으로는 동작 생성이 활성화되지 않는다.** 이 폴더의 `run_character_server.ipynb`를 Colab GPU 런타임에서 실행하고 안내에 따라 수정된 서버 파일과 `baby_idle.png`를 업로드한다. 기존 노트북의 실험/학습 코드는 변경하지 않았다.

프로젝트를 통째로 Colab에 올린 경우에는 아래 기존 실행법대로 **수정된** `app.py`, `motion_jobs.py`, `motion_generation.py`가 있는 폴더에서 실행해도 된다. 현재 로컬 변경을 원격 GitHub에 올리기 전에는 기존 `git clone`만으로 이 변경을 가져올 수 없다.

출력된 서버 주소로 앱 실행:

```sh
flutter run -d chrome --dart-define=CHARACTER_SERVER_URL=https://YOUR-SERVER.ngrok-free.app
```

동작 준비에는 기본 이미지 한 장 생성보다 시간이 더 걸린다. 앱은 기본 이미지를 먼저 보여주고 준비가 끝날 때까지 저장을 막는다. 실패하면 다시 생성하거나 기존 강아지를 유지할 수 있다.

### 생성 방식과 검증 범위

SD1.5 img2img로 기본 이미지를 참조해 6개 주요 자세를 만든다. 각 프레임을 개별 생성하지 않고, 공통 캔버스·발 기준점에 맞춘 자세 사이를 optical flow로 연결한다. 식사/호흡/목욕의 작은 움직임은 자세 이미지의 변형으로 반복한다.

같은 참조 이미지와 seed를 사용하더라도 SD1.5가 얼굴·무늬를 완전히 고정하거나 모든 자세 지시를 따르는 것을 보장하지 않는다. 실제 GPU 결과에서 외형, 다리 형태, 눕기/일어나기 전환을 확인해야 한다. CPU 테스트는 API 처리와 프레임 형식·연결을 검사하며 생성 품질을 평가하지 않는다.

작업과 결과는 한 서버 프로세스의 메모리에 보관하며 최대 8개 작업으로 제한한다. Colab용 단일 프로세스로 실행한다. 서버를 재시작하면 진행 중 작업이 사라지므로 앱에서 다시 생성해야 한다. 저장된 앱의 프레임은 서버 재시작 후에도 사용할 수 있다.

```sh
python -m unittest -v test_motion_generation
```

## 이 서버가 하는 일 / 안 하는 일

- `POST /generate` — 견종/색상/성격(한국어 텍스트) + seed를 받아 배경을 지운 강아지 캐릭터 PNG 한 장을 반환한다.
- **그림체 고정을 위해 img2img를 쓴다.** `Frontend/mira/assets/dog/baby_idle.png`(기존 강아지방 캐릭터)를 항상 기준 이미지로 두고, `strength=0.6`으로 텍스트(품종/색상/성격)만 반영해서 변형한다. txt2img로 매번 새로 그리면 실행할 때마다 그림체가 크게 달라져서(플랫 벡터 ↔ 실사 3D 렌더 ↔ 다른 동물처럼 보임 등) 이 방식으로 고정했다.
  - `strength`를 올릴수록(0.68+) 형태가 쉽게 깨지고(색이 이상해지거나 기형으로 나옴), 내릴수록(0.5 이하) 기준 이미지에서 거의 안 벗어난다. 여러 견종으로 테스트했을 때 0.6이 가장 안정적이었다.
- **업로드한 실제 사진 자체를 img2img 기준 이미지로 쓰는 것도 시도했지만 포기했다.** 사진마다 결과가 너무 들쭉날쭉했다(형태가 깨지거나, 스타일 변환이 거의 안 되고 사진을 잘라붙인 것처럼 나옴). 지금은 사진 업로드 여부와 무관하게 항상 `baby_idle.png`를 기준으로 쓴다.
- `emotion/FINAL.ipynb`처럼 **업로드한 실제 사진으로 LoRA를 파인튜닝해서 그 강아지를 닮은 캐릭터를 만드는 것도 포함하지 않는다.** LoRA 학습은 GPU로 몇 분~수십 분이 걸리는 별도의 오프라인 작업이라 앱의 실시간 흐름에 넣기 어렵다 (원본 `dog_lora_colab.ipynb` 참고).
  - 대신 앱의 "사진으로 만들기" 흐름은: 사진 업로드 → `Backend/ai-server`의 `/analyze-pet-photo`(Gemini Vision)로 품종/색상 텍스트 추출 → 그 텍스트를 이 서버의 `/generate`에 그대로 넘겨서 캐릭터를 만든다. 사용자의 특정 반려견과 완전히 똑같지는 않지만, 실시간으로 동작하는 현실적인 절충안이다.
  - 나중에 실제 반려견을 닮은 캐릭터가 필요해지면 `dog_lora_colab.ipynb`로 오프라인 학습 후 이 서버에 `pipe.load_lora_weights(...)`를 FINAL.ipynb처럼 추가하면 된다.

## 실행 (Colab 권장 — GPU 필요)

로컬에 CUDA GPU가 없다면 Colab에서 실행하고 ngrok로 터널링한다.

```python
# Colab 셀
!git clone https://github.com/kikimiya0606/capstone-project.git
%cd capstone-project/Backend/character-server
!pip install -q -r requirements.txt

from google.colab import userdata
from pyngrok import ngrok

# ngrok 토큰은 노트북에 평문으로 적지 말고 Colab Secrets(왼쪽 사이드바 열쇠 아이콘)에
# NGROK_AUTHTOKEN이라는 이름으로 등록해서 불러온다.
# (Backend/API/claude API 연동.ipynb에서 평문 토큰이 노출됐던 사고 이후로 이 방식으로 통일함 — BACKEND_STATUS.md 참고)
ngrok.set_auth_token(userdata.get('NGROK_AUTHTOKEN'))
public_url = ngrok.connect(5000)
print("API URL:", public_url)

!python app.py
```

`public_url`로 나온 주소(`https://xxxx.ngrok-free.dev`)를 mira 앱의
`Frontend/mira/lib/services/character_server_service.dart`에 있는
`_characterServerBaseUrl`에 넣어주면 된다.

로컬에 CUDA GPU가 있다면 그냥:

```bash
pip install -r requirements.txt
python app.py
```

## API

### `POST /generate`

`multipart/form-data`:

| 필드 | 설명 | 기본값 |
|---|---|---|
| breed | 견종 (한국어, 부분 일치 허용) | 포메라니안 |
| color | 색상 (한국어) | 흰색 |
| personality | 성격 (한국어, mira 앱의 PetSetup 선택지와 동일) | 활발함 |
| seed | 정수. 같은 값이면 같은 이미지 재생성 | 42 |

응답: `image/png` 바이너리.

### `GET /health`

상태 확인용.

## 참고

- 지원하는 한국어 표현은 `app.py`의 `BREED_MAP` / `COLOR_MAP` / `PERSONALITY_MAP`에 정의돼 있다. 목록에 없는 표현이 오면 부분 일치를 시도하고, 그래도 없으면 기본값으로 대체한다 — Stable Diffusion 1.5의 CLIP 텍스트 인코더가 한국어를 이해하지 못하기 때문에 알 수 없는 한국어를 프롬프트에 그대로 넣으면 결과가 무의미해진다.
- 원본 `emotion/photo.ipynb`는 노트북 파일 자체의 인코딩이 손상돼 있어 한글 딕셔너리 키를 그대로 복구할 수 없었다. 여기 있는 한국어 표기는 영어 프롬프트 값(`pomeranian`, `white` 등)에 맞춰 새로 정리한 것이다.
