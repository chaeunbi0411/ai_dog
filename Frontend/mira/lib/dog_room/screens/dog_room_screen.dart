import '../../widgets/word_wrap_text.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../controllers/dog_controller.dart';
import '../models/dog_state.dart';
import '../models/care_reminder.dart';
import '../widgets/care_action_bar.dart';
import '../widgets/dog_status_panel.dart';
import '../widgets/feeding_dog.dart';
import '../widgets/pet_wardrobe.dart';
import '../widgets/tail_wagging_dog.dart';

class DogRoomScreen extends StatefulWidget {
  const DogRoomScreen({
    super.key,
    required this.controller,
    this.onCareAction,
    this.careMessage,
    this.careReminder,
    this.careReminders = const [],
    this.petName = '강아지',
    this.onTalk,
    this.viewerUid,
    this.viewerAddress = '가족',
  });
  final DogController controller;
  final ValueChanged<CareAction>? onCareAction;
  final String? careMessage;
  final CareReminder? careReminder;
  final List<CareReminder> careReminders;
  final String petName;
  final VoidCallback? onTalk;
  final String? viewerUid;
  final String viewerAddress;

  @override
  State<DogRoomScreen> createState() => _DogRoomScreenState();
}

class _DogRoomScreenState extends State<DogRoomScreen>
    with TickerProviderStateMixin {
  final Random _random = Random();
  Timer? _moveTimer;
  Timer? _actionTimer;
  Timer? _frameTimer;
  Timer? _speechTimer;
  bool _speechVisible = true;
  CareReminder? _selectedReminder;
  final _waitedKeys = <String>{};
  List<CareReminder> get _waitingReminders =>
      _reminders.where((r) => r.uid != widget.viewerUid).toList();
  CareReminder? get _nextReminder {
    final pending = _waitingReminders;
    return pending.where((r) => !_waitedKeys.contains(r.key)).firstOrNull ??
        pending.firstOrNull;
  }

  int _speechIndex = 0;
  bool _growing = false;
  GrowthStage? _stageBeforeGrowth;
  int? _observedLevel;
  GrowthStage? _observedStage;
  List<CareReminder> get _reminders => [
    ...widget.careReminders,
    if (widget.careReminder != null) widget.careReminder!,
  ];
  String? _specialSpeech;
  double _dogX = 80;
  double _dogY = 100;
  bool _isMoving = false;
  bool _isFacingRight = true;
  bool _didPrecacheImages = false;
  bool _didSetInitialPosition = false;
  bool _isCareTransition = false;
  bool _waitingForCare = false;
  bool _greetingMember = false;
  bool _pettingDog = false;
  bool get _isTailWagging => _greetingMember || _pettingDog;
  Offset? _positionBeforeWaiting;
  CareAction? _activeAction;
  int _walkFrame = 0;
  late final AnimationController _breathingController;
  late final AnimationController _tapController;
  late final AnimationController _careController;
  Size _roomViewport = Size.zero;
  Duration _moveDuration = const Duration(seconds: 3);

  static const _babyWalkFrames = [
    'assets/dog/baby_walk_01.png',
    'assets/dog/baby_walk_02.png',
    'assets/dog/baby_walk_03.png',
    'assets/dog/baby_walk_04.png',
  ];

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _careController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    widget.controller.addListener(_refresh);
    if (!widget.controller.isLoading) {
      _observedLevel = widget.controller.state.level;
      _observedStage = widget.controller.state.stage;
    }
    widget.controller.initialize();
    _scheduleSpeechDismiss();
    _moveTimer = Timer(const Duration(seconds: 1), _moveDog);
    _frameTimer = Timer.periodic(const Duration(milliseconds: 125), (_) {
      if (!mounted || !_isMoving) {
        return;
      }
      setState(() => _walkFrame = (_walkFrame + 1) % _babyWalkFrames.length);
    });
  }

  @override
  void didUpdateWidget(covariant DogRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _waitedKeys.removeWhere((key) => !_reminders.any((r) => r.key == key));
    if (oldWidget.viewerUid != widget.viewerUid ||
        oldWidget.viewerAddress != widget.viewerAddress) {
      _specialSpeech = null;
      _speechIndex = 0;
    }
    if (_selectedReminder != null) {
      _selectedReminder = _reminders
          .where((r) => r.key == _selectedReminder!.key)
          .firstOrNull;
    }
    if (_waitingForCare &&
        !_waitingReminders.any((r) => r.key == _selectedReminder?.key)) {
      _moveTimer?.cancel();
      _tapController.reset();
      _waitingForCare = false;
      _selectedReminder = null;
      _specialSpeech = null;
      _greetingMember = false;
      _isMoving = false;
      _dogX = _positionBeforeWaiting?.dx ?? 80;
      _dogY = _positionBeforeWaiting?.dy ?? 100;
      _positionBeforeWaiting = null;
      _moveTimer = Timer(const Duration(seconds: 1), _moveDog);
    }
  }

  void _scheduleSpeechDismiss() {
    _speechTimer?.cancel();
    _speechTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _speechVisible = false);
    });
  }

  void _showSpeech([String? message]) {
    if (!mounted) return;
    setState(() {
      _specialSpeech = message;
      _speechVisible = true;
    });
    _scheduleSpeechDismiss();
  }

  void _refresh() {
    if (widget.controller.isLoading) return;
    final state = widget.controller.state;
    final previousLevel = _observedLevel;
    final previousStage = _observedStage;
    _observedLevel = state.level;
    _observedStage = state.stage;
    if (previousLevel != null && state.level > previousLevel && !_growing) {
      unawaited(_celebrateGrowth(previousStage!, previousLevel));
    } else if (!_growing) {
      _showSpeech();
    }
  }

  Future<void> _celebrateGrowth(
    GrowthStage previousStage,
    int previousLevel,
  ) async {
    setState(() {
      _growing = true;
      _stageBeforeGrowth = previousStage;
    });
    // Let the care animation finish before the transformation starts.
    await Future<void>.delayed(const Duration(milliseconds: 4400));
    if (!mounted) return;
    _moveTimer?.cancel();
    setState(() => _isMoving = false);
    _showSpeech('어라… 몸이 이상해요..! 간질간질해요!');
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() => _stageBeforeGrowth = null);
    final state = widget.controller.state;
    final gifts = <String>[
      if (previousLevel < 6 && state.level >= 6) '옷장과 분홍 리본',
      if (previousLevel < 16 && state.level >= 16) '방 꾸미기와 봄빛 배경',
      if (state.level >= 32) '새 성장 선물',
      if ([
        50,
        77,
        99,
      ].any((level) => previousLevel < level && state.level >= level))
        state.familyTitle!,
    ];
    _showSpeech(
      '뿅! Lv.${state.level}이 됐어요!'
      '${gifts.isEmpty ? ' 함께해 줘서 고마워요 ♥' : '\n${gifts.join(', ')} 해금!'}',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _growing = false);
    _moveTimer = Timer(const Duration(seconds: 1), _moveDog);
  }

  void _speakNeeds() {
    if (_growing) return;
    final address = widget.viewerAddress == '가족'
        ? ''
        : '${widget.viewerAddress}, ';
    final mine = _reminders.where((r) => r.uid == widget.viewerUid).firstOrNull;
    final state = widget.controller.state;
    final messages = [
      if (mine != null) mine.message.substring(mine.role.length).trim(),
      if (_waitingForCare && _selectedReminder?.uid != widget.viewerUid)
        '${_selectedReminder!.role} 기다리고 있어요. 같이 기다려 줄래요?',
      if (state.hunger < 40) '꼬르륵… 배고파요! 밥 주세요.',
      if (state.cleanliness < 40) '몸이 꼬질꼬질해요. 씻고 싶어요!',
      if (state.happiness < 40) '심심해요. 같이 놀아 줄래요?',
      if (state.energy < 40) '하암… 졸려요. 재워 주세요.',
    ];
    if (messages.isEmpty) {
      messages.addAll([
        '오늘도 같이 있어서 좋아요 ♥',
        '쓰다듬어 주면 꼬리가 절로 흔들려요!',
        '우리 오늘 뭐 하고 놀까요?',
      ]);
    }
    _showSpeech('$address${messages[_speechIndex++ % messages.length]}');
  }

  void _openWardrobe() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    builder: (_) =>
        PetWardrobe(controller: widget.controller, onMotion: _specialMotion),
  );

  Future<void> _specialMotion() async {
    if (_growing ||
        _waitingForCare ||
        _activeAction != null ||
        _isCareTransition ||
        _isTailWagging) {
      return;
    }
    _moveTimer?.cancel();
    setState(() {
      _isMoving = false;
      _pettingDog = true;
    });
    _showSpeech('우리 가족 최고! 신나게 인사해요 ♥');
    for (var i = 0; i < 3; i++) {
      await _tapController.forward(from: 0);
      if (!mounted) return;
    }
    setState(() => _pettingDog = false);
    _moveTimer = Timer(const Duration(seconds: 1), _moveDog);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didSetInitialPosition) {
      _didSetInitialPosition = true;
      final roomHeight = max(260.0, MediaQuery.sizeOf(context).height - 270);
      _dogY = roomHeight * .58;
    }
    if (_didPrecacheImages) return;
    _didPrecacheImages = true;
    for (final stage in GrowthStage.values) {
      precacheImage(AssetImage(stage.assetPath), context);
    }
    for (final frame in _babyWalkFrames) {
      precacheImage(AssetImage(frame), context);
    }
    precacheImage(const AssetImage('assets/dog/baby_wait.png'), context);
    precacheImage(const AssetImage('assets/dog/baby_eat.png'), context);
    precacheImage(
      const AssetImage('assets/room/entrance_background.png'),
      context,
    );
    precacheImage(const AssetImage('assets/dog/baby_sleep.png'), context);
    precacheImage(const AssetImage('assets/room/room_background.png'), context);
    precacheImage(const AssetImage('assets/furniture/bed.png'), context);
    precacheImage(const AssetImage('assets/furniture/food_bowl.png'), context);
    precacheImage(const AssetImage('assets/furniture/bathtub.png'), context);
  }

  void _moveDog() {
    if (!mounted ||
        _activeAction != null ||
        _isCareTransition ||
        _growing ||
        _waitingForCare) {
      return;
    }
    final size = _roomViewport == Size.zero
        ? MediaQuery.sizeOf(context)
        : _roomViewport;
    const dogSize = 140.0;
    final maxX = max(20.0, size.width - dogSize - 20);
    final roomHeight = _roomViewport == Size.zero
        ? max(260.0, size.height - 270)
        : size.height;
    final minY = roomHeight * .46;
    final maxY = max(minY, roomHeight - dogSize - 8);
    var nextX = _dogX;
    var nextY = _dogY;
    for (var attempt = 0; attempt < 16; attempt++) {
      final candidateX = 20 + _random.nextDouble() * max(0, maxX - 20);
      final candidateY = minY + _random.nextDouble() * max(0, maxY - minY);
      if (!_isRoamingPositionBlocked(candidateX, candidateY, size)) {
        nextX = candidateX;
        nextY = candidateY;
        break;
      }
    }
    setState(() {
      _moveDuration = const Duration(seconds: 3);
      if ((nextX - _dogX).abs() > 1) {
        _isFacingRight = nextX > _dogX;
      }
      _dogX = nextX;
      _dogY = nextY;
      _isMoving = true;
    });
    _moveTimer?.cancel();
    _moveTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _isMoving = false);
      _walkFrame = 0;
      _moveTimer = Timer(Duration(seconds: 2 + _random.nextInt(4)), _moveDog);
    });
  }

  bool _isRoamingPositionBlocked(double x, double y, Size roomSize) {
    final dogFeet = Rect.fromLTWH(x + 22, y + 88, 96, 44);
    final bedZone = Rect.fromLTWH(
      max(0, roomSize.width - 184),
      max(0, roomSize.height - 202),
      176,
      132,
    );
    final bowlZone = Rect.fromLTWH(6, max(0, roomSize.height - 92), 102, 82);
    final bathtubZone = Rect.fromLTWH(
      4,
      max(0, roomSize.height - 258),
      184,
      164,
    );
    return dogFeet.overlaps(bedZone) ||
        dogFeet.overlaps(bowlZone) ||
        dogFeet.overlaps(bathtubZone);
  }

  Future<void> _handleDogTap() async {
    if (_isMoving ||
        _activeAction != null ||
        _isCareTransition ||
        _growing ||
        (_waitingForCare || _tapController.isAnimating)) {
      return;
    }
    _moveTimer?.cancel();
    setState(() {
      _isMoving = false;
      _walkFrame = 0;
      _pettingDog = true;
    });
    await _tapController.forward(from: 0);
    if (!mounted) return;
    setState(() => _pettingDog = false);
    _moveTimer = Timer(const Duration(milliseconds: 900), _moveDog);
  }

  Future<void> _performCare(CareAction action) async {
    if (_activeAction != null ||
        _isCareTransition ||
        _growing ||
        _waitingForCare ||
        _pettingDog) {
      return;
    }
    _moveTimer?.cancel();
    if (action == CareAction.feed ||
        action == CareAction.wash ||
        action == CareAction.sleep) {
      final targetX = switch (action) {
        CareAction.feed => 16.0,
        CareAction.wash => 24.0,
        CareAction.sleep => max(12.0, _roomViewport.width - 166),
        CareAction.play => _dogX,
      };
      final targetY = switch (action) {
        CareAction.feed => max(72.0, _roomViewport.height - 156),
        CareAction.wash => max(72.0, _roomViewport.height - 220),
        CareAction.sleep => max(72.0, _roomViewport.height - 225),
        _ => max(72.0, _roomViewport.height - 154),
      };
      setState(() {
        _isCareTransition = true;
        _moveDuration = const Duration(milliseconds: 900);
        _isFacingRight = targetX > _dogX;
        _dogX = targetX;
        _dogY = targetY;
        _isMoving = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 950));
      if (!mounted) return;
    }
    final succeeded = await widget.controller.care(action);
    if (!mounted) return;
    if (!succeeded) {
      setState(() {
        _isCareTransition = false;
        _isMoving = false;
      });
      _moveTimer = Timer(const Duration(seconds: 1), _moveDog);
      return;
    }

    widget.onCareAction?.call(action);
    _moveTimer?.cancel();
    setState(() {
      _isCareTransition = false;
      _activeAction = action;
      _isMoving = false;
      if (action == CareAction.feed) _isFacingRight = false;
      if (action == CareAction.wash) _isFacingRight = true;
    });
    if (action == CareAction.feed) {
      _careController.duration = const Duration(milliseconds: 4200);
      _careController.forward(from: 0);
    } else if (action == CareAction.sleep) {
      _careController.duration = const Duration(milliseconds: 650);
      _careController.forward(from: 0);
    } else if (action == CareAction.wash || action == CareAction.play) {
      _careController.duration = const Duration(milliseconds: 460);
      _careController.repeat();
    }
    _actionTimer?.cancel();
    _actionTimer = Timer(
      Duration(milliseconds: action == CareAction.feed ? 4200 : 1700),
      () {
        if (!mounted) return;
        _careController.stop();
        _careController.reset();
        setState(() => _activeAction = null);
        _moveTimer = Timer(const Duration(milliseconds: 700), _moveDog);
      },
    );
  }

  void _waitForCare(CareReminder reminder) {
    if (_waitingForCare ||
        _activeAction != null ||
        _isCareTransition ||
        _growing ||
        _pettingDog) {
      return;
    }
    _speechTimer?.cancel();
    _positionBeforeWaiting = Offset(_dogX, _dogY);
    _moveTimer?.cancel();
    _tapController.reset();
    setState(() {
      if (_waitingReminders.every((r) => _waitedKeys.contains(r.key))) {
        _waitedKeys.clear();
      }
      _waitedKeys.add(reminder.key);
      _selectedReminder = reminder;
      _waitingForCare = true;
      _speechVisible = true;
      _specialSpeech = null;
      _greetingMember = false;
      _isMoving = true;
      _moveDuration = const Duration(milliseconds: 900);
      final targetX = max(0.0, (_roomViewport.width - 140) / 2);
      _isFacingRight = targetX > _dogX;
      _dogX = targetX;
      _dogY = max(64.0, _roomViewport.height * .57 - 100);
    });
    _scheduleSpeechDismiss();
    _moveTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _isMoving = false;
        _isFacingRight = true;
      });
    });
  }

  Future<void> _greetMember() async {
    if (!_waitingForCare || _greetingMember || _isMoving) return;
    _showSpeech();
    _moveTimer?.cancel();
    setState(() {
      _isMoving = false;
      _greetingMember = true;
      _isFacingRight = true;
      _walkFrame = 0;
    });
    for (var bounce = 0; bounce < 3; bounce++) {
      await _tapController.forward(from: 0);
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() {
      _waitingForCare = false;
      _greetingMember = false;
      _dogX = _positionBeforeWaiting?.dx ?? 80;
      _dogY = _positionBeforeWaiting?.dy ?? 100;
      _positionBeforeWaiting = null;
    });
    _moveTimer = Timer(const Duration(seconds: 1), _moveDog);
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    _actionTimer?.cancel();
    _frameTimer?.cancel();
    _speechTimer?.cancel();
    _breathingController.dispose();
    _tapController.dispose();
    _careController.dispose();
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final state = widget.controller.state;
    final visibleStage = _stageBeforeGrowth ?? state.stage;
    final isBabySleeping =
        visibleStage == GrowthStage.baby && _activeAction == CareAction.sleep;
    final isBabyWaiting =
        visibleStage == GrowthStage.baby &&
        _waitingForCare &&
        !_greetingMember &&
        !_isMoving;
    final dogAsset = isBabyWaiting
        ? 'assets/dog/baby_wait.png'
        : visibleStage == GrowthStage.baby && _isMoving
        ? _babyWalkFrames[_walkFrame]
        : isBabySleeping
        ? 'assets/dog/baby_sleep.png'
        : visibleStage.assetPath;
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: _RoomLayout(
          children: [
            if (_nextReminder != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        _activeAction != null ||
                            _isCareTransition ||
                            _growing ||
                            _isTailWagging ||
                            (_waitingForCare && _isMoving)
                        ? null
                        : _waitingForCare
                        ? _greetMember
                        : () => _waitForCare(_nextReminder!),
                    icon: Icon(
                      _waitingForCare
                          ? Icons.favorite_outline
                          : Icons.door_front_door_outlined,
                      size: 16,
                    ),
                    label: WordSafeText(
                      _waitingForCare
                          ? '\uBC29\uC73C\uB85C \uB3CC\uC544\uAC00\uAE30'
                          : '${_nextReminder!.role} \uAE30\uB2E4\uB9AC\uAE30',
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
            DogStatusPanel(state: state, petName: widget.petName),
            TextButton.icon(
              onPressed: _growing ? null : _openWardrobe,
              icon: Icon(
                state.wardrobeUnlocked ? Icons.checkroom : Icons.lock_outline,
                size: 18,
              ),
              label: WordSafeText(
                state.wardrobeUnlocked ? '옷장 · 성장 선물' : '옷장 · Lv.6에 해금',
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _roomViewport = constraints.biggest;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          _waitingForCare
                              ? 'assets/room/entrance_background.png'
                              : 'assets/room/room_background.png',
                          key: ValueKey(
                            _waitingForCare
                                ? 'entrance-background'
                                : 'room-background',
                          ),
                          fit: _waitingForCare ? BoxFit.fill : BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
                      if (!_waitingForCare &&
                          state.roomTheme != 'default' &&
                          state.canUseTheme(state.roomTheme))
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: state.roomTheme == 'spring'
                                      ? [
                                          const Color(0x447FCF94),
                                          const Color(0x44FFD0DE),
                                        ]
                                      : [
                                          const Color(0x886B60AF),
                                          const Color(0x336CA9E6),
                                        ],
                                ),
                              ),
                              child: state.roomTheme == 'starlight'
                                  ? const Align(
                                      alignment: Alignment.topCenter,
                                      child: WordSafeText(
                                        '✧     ⋆     ✧     ⋆     ✧',
                                        style: TextStyle(
                                          fontSize: 32,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      if (!_waitingForCare)
                        Positioned(
                          right: 12,
                          bottom: 68,
                          child: Image.asset(
                            'assets/furniture/bed.png',
                            width: 162,
                            fit: BoxFit.contain,
                          ),
                        ),
                      if (!_waitingForCare)
                        Positioned(
                          left: 18,
                          bottom: 18,
                          child: Image.asset(
                            'assets/furniture/food_bowl.png',
                            width: 68,
                            fit: BoxFit.contain,
                          ),
                        ),
                      if (!_waitingForCare)
                        Positioned(
                          left: 8,
                          bottom: 86,
                          child: Image.asset(
                            'assets/furniture/bathtub.png',
                            width: 174,
                            fit: BoxFit.contain,
                          ),
                        ),
                      if (_activeAction == CareAction.sleep)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _careController,
                            builder: (context, _) => ColoredBox(
                              color: const Color(
                                0xFF26344A,
                              ).withValues(alpha: .18 * _careController.value),
                            ),
                          ),
                        ),
                      AnimatedPositioned(
                        key: const ValueKey('dog-position'),
                        duration: _moveDuration,
                        curve: Curves.easeInOut,
                        left: _dogX.clamp(
                          0,
                          max(0, constraints.maxWidth - 140),
                        ),
                        top: _dogY.clamp(
                          64,
                          max(64, constraints.maxHeight - 140),
                        ),
                        child: GestureDetector(
                          onTap: _handleDogTap,
                          child: AnimatedBuilder(
                            animation: Listenable.merge([
                              _breathingController,
                              _tapController,
                              _careController,
                            ]),
                            builder: (context, child) {
                              final breathing =
                                  !_isMoving &&
                                      _activeAction == null &&
                                      !_isTailWagging
                                  ? _breathingController.value
                                  : 0.0;
                              final tapBounce = _isTailWagging
                                  ? 0.0
                                  : sin(pi * _tapController.value) *
                                        (1 - _tapController.value);
                              final walking = _isMoving && _walkFrame.isOdd
                                  ? 1.0
                                  : 0.0;
                              final playing = _activeAction == CareAction.play
                                  ? sin(pi * _careController.value)
                                  : 0.0;
                              return Transform.rotate(
                                angle: 0,
                                alignment: Alignment.bottomCenter,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    -2 * breathing -
                                        6 * tapBounce +
                                        3 * walking -
                                        8 * playing,
                                  ),
                                  child: Transform.scale(
                                    scaleX:
                                        1 + .018 * breathing + .012 * tapBounce,
                                    scaleY:
                                        1 + .018 * breathing + .012 * tapBounce,
                                    alignment: Alignment.bottomCenter,
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: _activeAction == CareAction.feed
                                ? Transform.flip(
                                    flipX: true,
                                    child: FeedingDog(
                                      animation: _careController,
                                      idleAsset: visibleStage.assetPath,
                                      eatingAsset:
                                          visibleStage == GrowthStage.baby
                                          ? 'assets/dog/baby_eat.png'
                                          : null,
                                    ),
                                  )
                                : AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 900),
                                    switchInCurve: Curves.easeOutBack,
                                    switchOutCurve: Curves.easeIn,
                                    transitionBuilder: (child, animation) =>
                                        _waitingForCare
                                        ? FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          )
                                        : FadeTransition(
                                            opacity: animation,
                                            child: ScaleTransition(
                                              scale: Tween<double>(
                                                begin: .72,
                                                end: 1,
                                              ).animate(animation),
                                              child: child,
                                            ),
                                          ),
                                    child: Transform.flip(
                                      key: ValueKey((
                                        visibleStage,
                                        isBabySleeping,
                                        isBabyWaiting,
                                      )),
                                      flipX: !_isFacingRight,
                                      child: _isTailWagging
                                          ? TailWaggingDog(
                                              asset: visibleStage.assetPath,
                                              animation: _tapController,
                                            )
                                          : Image.asset(
                                              dogAsset,
                                              width: 140,
                                              height: 140,
                                              fit: BoxFit.contain,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Image.asset(
                                                    visibleStage.assetPath,
                                                    width: 140,
                                                    height: 140,
                                                    fit: BoxFit.contain,
                                                  ),
                                            ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      if (state.accessory != 'none' &&
                          state.canWear(state.accessory))
                        AnimatedPositioned(
                          duration: _moveDuration,
                          curve: Curves.easeInOut,
                          left:
                              _dogX.clamp(
                                0,
                                max(0, constraints.maxWidth - 140),
                              ) +
                              52,
                          top:
                              _dogY.clamp(
                                64,
                                max(64, constraints.maxHeight - 140),
                              ) +
                              (state.accessory == 'crown' ? 12 : 87),
                          child: IgnorePointer(
                            child: WordSafeText(
                              state.accessory == 'crown' ? '👑' : '🎀',
                              style: const TextStyle(fontSize: 30),
                            ),
                          ),
                        ),
                      if (_growing)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(_stageBeforeGrowth),
                                tween: Tween(begin: .5, end: 1),
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.elasticOut,
                                builder: (_, value, child) =>
                                    Transform.scale(scale: value, child: child),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  size: 100,
                                  color: Color(0xFFFFD76D),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: (_dogX + 86).clamp(
                          8,
                          max(8, constraints.maxWidth - 54),
                        ),
                        top: (_dogY + 5).clamp(
                          52,
                          max(52, constraints.maxHeight - 54),
                        ),
                        child: AnimatedBuilder(
                          animation: _tapController,
                          builder: (context, child) {
                            final progress = _tapController.value;
                            final opacity = sin(pi * progress).clamp(0.0, 1.0);
                            return IgnorePointer(
                              child: Opacity(
                                opacity: opacity,
                                child: Transform.translate(
                                  offset: Offset(0, -48 * progress),
                                  child: Transform.scale(
                                    scale: .7 + .5 * progress,
                                    child: child,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.favorite,
                            color: Color(0xFFE86A76),
                            size: 36,
                          ),
                        ),
                      ),
                      if (_activeAction != null &&
                          _activeAction != CareAction.feed)
                        Positioned(
                          left:
                              (_dogX +
                                      (_activeAction == CareAction.wash
                                          ? 5
                                          : 82))
                                  .clamp(
                                    10,
                                    max(
                                      10,
                                      constraints.maxWidth -
                                          (_activeAction == CareAction.wash
                                              ? 135
                                              : 90),
                                    ),
                                  ),
                          top:
                              (_dogY +
                                      (_activeAction == CareAction.wash
                                          ? 20
                                          : -8))
                                  .clamp(
                                    58,
                                    max(
                                      58,
                                      constraints.maxHeight -
                                          (_activeAction == CareAction.wash
                                              ? 115
                                              : 100),
                                    ),
                                  ),
                          child: _activeAction == CareAction.wash
                              ? _BathBubbles(animation: _careController)
                              : _activeAction == CareAction.play
                              ? _PlayBall(animation: _careController)
                              : _activeAction == CareAction.sleep
                              ? _SleepZzz(animation: _breathingController)
                              : _CareEffect(
                                  key: ValueKey(_activeAction),
                                  action: _activeAction!,
                                ),
                        ),
                      AnimatedPositioned(
                        duration: _moveDuration,
                        curve: Curves.easeInOut,
                        left:
                            (_dogX.clamp(
                                      0,
                                      max(0, constraints.maxWidth - 140),
                                    ) +
                                    70 -
                                    min(240.0, constraints.maxWidth - 16) / 2)
                                .clamp(
                                  8,
                                  max(
                                    8,
                                    constraints.maxWidth -
                                        min(240.0, constraints.maxWidth - 16) -
                                        8,
                                  ),
                                ),
                        top: max(
                          8,
                          _dogY.clamp(
                                64,
                                max(64, constraints.maxHeight - 140),
                              ) -
                              (_speechVisible ? 76 : 20),
                        ),
                        child: SizedBox(
                          width: min(240.0, constraints.maxWidth - 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_speechVisible)
                                Container(
                                  key: const ValueKey('dog-speech'),
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    14,
                                    8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFDF8),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: const Color(0xFFEADCCD),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x18000000),
                                        blurRadius: 16,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      WordSafeText(
                                        _specialSpeech ??
                                            (_waitingForCare
                                                ? _selectedReminder?.message
                                                : null) ??
                                            widget.careMessage ??
                                            widget.controller.message,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF665345),
                                          fontSize: 13,
                                          height: 1.4,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: IconButton.filledTonal(
                                    key: const ValueKey('dog-speech-toggle'),
                                    tooltip: '강아지 마음 듣기',
                                    onPressed: _speakNeeds,
                                    icon: const Icon(
                                      Icons.priority_high_rounded,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              if (_speechVisible)
                                const Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: Color(0xFFFFFDF8),
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (widget.onTalk != null)
              TextButton.icon(
                onPressed: widget.onTalk,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const WordSafeText('강아지와 대화하기'),
              ),
            CareActionBar(
              onAction: _performCare,
              enabled:
                  _activeAction == null &&
                  !_isCareTransition &&
                  !_growing &&
                  !_waitingForCare &&
                  !_pettingDog,
            ),
          ],
        ),
      ),
    );
  }
}

/// Keep the room usable when text or a landscape viewport needs more height.
class _RoomLayout extends StatelessWidget {
  const _RoomLayout({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final controlsHeight = (360 + max(0, children.length - 4) * 48) * scale;
      final roomHeight = max(280.0, constraints.maxHeight - controlsHeight);
      return SingleChildScrollView(
        child: Column(
          children: [
            for (final child in children)
              if (child is Expanded)
                SizedBox(height: roomHeight, child: child.child)
              else
                child,
          ],
        ),
      );
    },
  );
}

class _SleepZzz extends StatelessWidget {
  const _SleepZzz({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 72,
        height: 92,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final progress = animation.value;
            return Opacity(
              opacity: sin(pi * progress).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(8 * progress, -34 * progress),
                child: Transform.scale(
                  scale: .75 + .35 * progress,
                  child: const WordSafeText(
                    'Zzz',
                    style: TextStyle(
                      color: Color(0xFF7E78C8),
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.white, blurRadius: 5)],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlayBall extends StatelessWidget {
  const _PlayBall({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 76,
        height: 90,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final progress = animation.value;
            final height = sin(pi * progress) * 48;
            return Transform.translate(
              offset: Offset(-38 * progress, 24 - height),
              child: Transform.rotate(angle: progress * pi * 2, child: child),
            );
          },
          child: const Icon(
            Icons.sports_baseball,
            size: 34,
            color: Color(0xFFE86A76),
            shadows: [Shadow(color: Color(0x55000000), blurRadius: 5)],
          ),
        ),
      ),
    );
  }
}

class _BathBubbles extends StatelessWidget {
  const _BathBubbles({required this.animation});

  final Animation<double> animation;

  static const _bubbles = <(double, double, double, double)>[
    (2, 58, 18, 0),
    (30, 78, 13, .18),
    (56, 50, 21, .36),
    (82, 72, 15, .54),
    (105, 42, 19, .72),
    (43, 22, 11, .86),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 130,
        height: 110,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) => Stack(
            children: [
              for (final bubble in _bubbles)
                _buildBubble(
                  bubble.$1,
                  bubble.$2,
                  bubble.$3,
                  (animation.value + bubble.$4) % 1,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(
    double left,
    double bottom,
    double size,
    double progress,
  ) {
    final opacity = sin(pi * progress).clamp(0.0, 1.0);
    return Positioned(
      left: left + sin(progress * pi * 2) * 5,
      bottom: bottom + progress * 38,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFDDF7FF).withValues(alpha: .72),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x5568B9D8), blurRadius: 5),
            ],
          ),
        ),
      ),
    );
  }
}

class _CareEffect extends StatelessWidget {
  const _CareEffect({super.key, required this.action});
  final CareAction action;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (action) {
      CareAction.feed => (Icons.restaurant, '냠냠!', const Color(0xFFF2A65A)),
      CareAction.wash => (Icons.bubble_chart, '뽀글뽀글', const Color(0xFF68B9D8)),
      CareAction.play => (
        Icons.sports_baseball,
        '신난다!',
        const Color(0xFFE86A76),
      ),
      CareAction.sleep => (Icons.bedtime, 'Zzz', const Color(0xFF7E78C8)),
    };
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, -18 * value),
        child: Transform.scale(scale: .45 + .55 * value, child: child),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: .3), blurRadius: 14),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 5),
              WordSafeText(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
