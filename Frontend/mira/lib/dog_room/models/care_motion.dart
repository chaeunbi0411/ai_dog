import '../controllers/dog_controller.dart';

enum CarePhase { approaching, entering, acting, exiting, returning }

String careClip(CareAction action, CarePhase phase) => switch (phase) {
  CarePhase.approaching || CarePhase.returning => 'walk',
  CarePhase.entering => '${action.name}_enter',
  CarePhase.acting => action.name,
  CarePhase.exiting => '${action.name}_exit',
};

String careSpeech(CareAction action, CarePhase phase) {
  if (phase == CarePhase.returning) return switch (action) {
    CareAction.feed => '잘 먹었어요! 다시 놀러 갈게요.',
    CareAction.wash => '보송보송 깨끗해졌어요! 돌아갈게요.',
    CareAction.play => '정말 재미있었어요! 돌아갈게요.',
    CareAction.sleep => '잘 잤어요! 기지개 켜고 걸어 볼까요?',
  };
  if (phase == CarePhase.approaching) return switch (action) {
    CareAction.feed => '밥 먹으러 갈게요!',
    CareAction.wash => '씻으러 갈게요!',
    CareAction.play => '같이 놀러 가요!',
    CareAction.sleep => '졸려요… 침대로 갈게요.',
  };
  if (phase == CarePhase.exiting) return switch (action) {
    CareAction.feed => '배부르다! 고개를 들고…',
    CareAction.wash => '물기를 털고 나갈게요!',
    CareAction.play => '후우! 잠깐 숨을 고를게요.',
    CareAction.sleep => '하암… 잘 잤다! 일어날게요.',
  };
  return switch (action) {
    CareAction.feed => '냠냠! 맛있게 먹고 있어요.',
    CareAction.wash => '뽀득뽀득! 씻고 있어요.',
    CareAction.play => '신나요! 같이 놀아요!',
    CareAction.sleep => phase == CarePhase.entering ? '포근해요… 누울게요.' : '쿨쿨… Zzz',
  };
}
