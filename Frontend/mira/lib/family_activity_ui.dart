part of 'main.dart';

class _ActivityBuilder extends StatefulWidget {
  const _ActivityBuilder({required this.builder});
  final Widget Function(BuildContext, FamilyActivity) builder;
  @override
  State<_ActivityBuilder> createState() => _ActivityBuilderState();
}

class _ActivityBuilderState extends State<_ActivityBuilder> {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _data = <String, List<Map<String, dynamic>>>{};
  final _errors = <String>{};
  Timer? _timer;
  String? _message;
  String? _familyId;
  @override
  void initState() {
    super.initState();
    _connect();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _connect() async {
    final uid = currentUidOrNull();
    if (uid == null) {
      setState(() => _message = '로그인 후 가족 기록을 볼 수 있어요.');
      return;
    }
    try {
      final familyId = await FamilyService.instance.fetchMyFamilyId(uid);
      if (!mounted) return;
      if (familyId == null) {
        setState(() => _message = '가족에 참여하면 기록이 모여요.');
        return;
      }
      _familyId = familyId;
      final db = FirebaseFirestore.instance;
      void watch(String name, Query<Map<String, dynamic>> query) {
        _subscriptions.add(
          query.snapshots().listen(
            (s) {
              if (mounted) {
                setState(() {
                  _data[name] = s.docs
                      .map((d) => {...d.data(), 'uid': d.id})
                      .toList();
                  _errors.remove(name);
                });
              }
            },
            onError: (Object error) {
              if (mounted) setState(() => _errors.add(name));
            },
          ),
        );
      }

      watch(
        'members',
        db.collection('users').where('familyId', isEqualTo: familyId),
      );
      for (final c in ['moments', 'photos', 'moods', 'dailyCare']) {
        watch(c, db.collection('families').doc(familyId).collection(c));
      }
    } catch (_) {
      if (mounted) setState(() => _message = '가족 기록을 불러오지 못했어요. 다시 접속해주세요.');
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_message != null) return Text(_message!);
    if (_errors.isNotEmpty) return const Text('가족 기록을 불러오지 못했어요. 연결을 확인해주세요.');
    if (_data.length < 5) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    return widget.builder(
      context,
      FamilyActivity(
        familyId: _familyId!,
        members: _data['members']!,
        moments: _data['moments']!,
        photos: _data['photos']!,
        moods: _data['moods']!,
        care: _data['dailyCare']!,
        now: koreaNow(),
      ),
    );
  }
}

class _WeeklyQuests extends StatelessWidget {
  const _WeeklyQuests({required this.onStory, required this.onPhoto});
  final VoidCallback onStory, onPhoto;
  @override
  Widget build(BuildContext context) => _ActivityBuilder(
    builder: (context, data) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Section('가족 퀘스트', '이번 주 ${data.questsDone} / 2'),
        const SizedBox(height: 4),
        const Text(
          '월요일마다 새로 시작해요 · 완료 시 각각 에너지 +40',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        QuestCard(
          icon: '🍽️',
          title: '가족 모두 이번 주 이야기 하나씩',
          detail:
              '${data.participants} / ${data.members.length}명 기록 · 눌러서 마음 남기기',
          progress: data.members.isEmpty
              ? 0
              : data.participants / data.members.length,
          color: const Color(0xFFFFE8CF),
          onTap: onStory,
        ),
        const SizedBox(height: 12),
        QuestCard(
          icon: '📷',
          title: '우리 가족 이번 주 한 컷',
          detail: data.photoDone ? '사진 공유 완료 · 사진첩 보기' : '눌러서 사진첩에 사진 한 장 남기기',
          progress: data.photoDone ? 1 : 0,
          color: const Color(0xFFDDECE3),
          onTap: onPhoto,
        ),
      ],
    ),
  );
}

class _LiveMetrics extends StatelessWidget {
  const _LiveMetrics({required this.onEmotion, required this.onFamily});
  final VoidCallback onEmotion, onFamily;
  @override
  Widget build(BuildContext context) => _ActivityBuilder(
    builder: (_, data) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '오늘의 감정',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Metric(
                '☀️',
                '패밀리 무드',
                data.moodPercent == null ? '기록 전' : '${data.moodPercent}%',
                description: '개인 감정 기록의 기쁨 비율 · ${data.todayMoods.length}명 참여',
              ),
              TextButton(onPressed: onEmotion, child: const Text('나의 감정 기록하기')),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '가족 활동',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Metric(
                '⚡',
                '패밀리 에너지',
                '${data.energy}',
                description: '공유 글·사진·좋아요·돌봄·퀘스트로 쌓은 이번 주 점수',
              ),
              TextButton(onPressed: onFamily, child: const Text('가족 이야기 남기기')),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LiveInteraction extends StatelessWidget {
  const _LiveInteraction();
  @override
  Widget build(BuildContext context) => _ActivityBuilder(
    builder: (_, data) => Column(
      children: [
        const Section('가족 상호작용', '이번 주'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: data.questsDone / 2,
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 12),
                Text(
                  '공유 글 ${data.weekMoments.length} · 사진 ${data.weekPhotos.length} · 좋아요 ${data.likes} · 돌봄 ${data.careCount}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class AiPage extends StatefulWidget {
  const AiPage({super.key});
  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _history = <Map<String, String>>[];
  bool _busy = false;
  String? _error, _pending;
  bool _signalRequested = false, _signalBusy = false;
  String? _signal, _signalError, _interactionSummary;

  /// 댓글/좋아요 교류를 집계해 소통이 뜸한 관계를 AI가 한 문장으로 짚어주는
  /// "소통 신호" 카드. 인사이트 탭을 열 때 한 번만 계산해서, 매번 다시 만들지
  /// 않고 이후 채팅 질문에도 같은 교류 데이터를 함께 넘겨준다.
  Future<void> _loadSignal(FamilyActivity data) async {
    if (!mounted || data.members.length < 2) return;
    setState(() {
      _signalBusy = true;
      _signalError = null;
    });
    try {
      final matrix = await FamilyInteractionService.instance.build(
        familyId: data.familyId,
        moments: data.moments,
        photos: data.photos,
        since: data.now.subtract(const Duration(days: 28)),
      );
      if (!mounted) return;
      final summary = matrix.summaryText(data.members);
      setState(() => _interactionSummary = summary);
      final reply = await AiServerService.instance.familySignal(
        familyContext: data.contextText(),
        interactionSummary: summary,
      );
      if (!mounted) return;
      setState(() => _signal = reply);
    } on AiServerException catch (e) {
      if (mounted) setState(() => _signalError = e.message);
    } catch (_) {
      if (mounted) setState(() => _signalError = '소통 신호를 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => _signalBusy = false);
    }
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });
  Future<void> _send(FamilyActivity data, {String? retry}) async {
    final message = retry ?? _input.text.trim();
    if (message.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _pending = message;
      _input.clear();
    });
    _scrollToEnd();
    try {
      final reply = await AiServerService.instance.chatInsight(
        message: message,
        familyContext: data.contextText(
          interactionSummary: _interactionSummary,
        ),
        history: _history
            .skip((_history.length - 12).clamp(0, _history.length))
            .toList(),
      );
      if (!mounted) return;
      setState(() {
        _history.addAll([
          {'role': 'user', 'text': message},
          {'role': 'model', 'text': reply},
        ]);
        _pending = null;
      });
    } on AiServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollToEnd();
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ActivityBuilder(
    builder: (context, data) {
      if (!_signalRequested && data.members.length >= 2) {
        _signalRequested = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadSignal(data));
      }
      return Column(
        children: [
          Expanded(
            child: AppPage(
              title: 'MIRA 인사이트',
              controller: _scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          CupertinoIcons.sparkles,
                          color: Color(0xFFDCD8FF),
                          size: 28,
                        ),
                        const SizedBox(height: 16),
                        const WordWrapText(
                          '우리 가족의 이야기를 함께 살펴봐요.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '이번 주 공유 글 ${data.weekMoments.length} · 사진 ${data.weekPhotos.length} · 돌봄 ${data.careCount}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Section('살펴볼 신호', '이번 주'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Insight(
                            '이야기 나눔',
                            '${data.participants}명',
                            '이번 주 이야기를 남긴 가족',
                          ),
                          const Divider(height: 28),
                          Insight(
                            '함께한 돌봄',
                            '${data.careCount}회',
                            '실제로 완료한 강아지 돌봄',
                          ),
                          const Divider(height: 28),
                          Insight(
                            '가족의 반응',
                            '${data.likes}개',
                            '이번 주 글과 사진에 남은 좋아요',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (data.members.length >= 2) ...[
                    const SizedBox(height: 20),
                    const Section('AI 소통 신호', '최근 4주'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              CupertinoIcons.heart_circle,
                              color: violet,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _signalError != null
                                  ? WordWrapText(
                                      _signalError!,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    )
                                  : WordWrapText(
                                      _signal ??
                                          (_signalBusy
                                              ? '가족의 댓글·좋아요를 살펴보고 있어요…'
                                              : '아직 살펴볼 만큼 교류가 쌓이지 않았어요.'),
                                      style: const TextStyle(height: 1.5),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    '가족이 공유한 이야기와 프로필을 참고해 대화해요.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  if (_history.isEmpty && _pending == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        '궁금한 이야기를 편하게 건네주세요.',
                        style: TextStyle(color: Colors.black45),
                      ),
                    ),
                  for (final turn in _history)
                    _InsightBubble(
                      text: turn['text']!,
                      mine: turn['role'] == 'user',
                    ),
                  if (_pending != null)
                    _InsightBubble(text: _pending!, mine: true),
                  if (_busy)
                    const _InsightBubble(text: '답변을 생각하고 있어요…', mine: false),
                  if (_error != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _send(data, retry: _pending),
                          child: const Text('다시 보내기'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: const Border(top: BorderSide(color: Color(0xFFEAE6DF))),
            ),
            child: TextField(
              controller: _input,
              enabled: !_busy,
              maxLength: 1000,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(data),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'MIRA에게 이야기하기',
                suffixIcon: IconButton(
                  tooltip: '보내기',
                  onPressed: _busy ? null : () => _send(data),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _InsightBubble extends StatelessWidget {
  const _InsightBubble({required this.text, required this.mine});
  final String text;
  final bool mine;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: constraints.maxWidth * .88),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFEDE9F8) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mine ? '나' : 'MIRA',
              style: const TextStyle(
                fontSize: 11,
                color: violet,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            SelectionArea(
              child: WordWrapText(text, style: const TextStyle(height: 1.6)),
            ),
          ],
        ),
      ),
    ),
  );
}
