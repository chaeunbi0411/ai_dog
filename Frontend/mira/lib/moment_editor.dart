part of 'main.dart';

Future<void> editMoment(
  BuildContext context,
  String familyId,
  String id,
  Map<String, dynamic> data,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MomentEditor(familyId: familyId, id: id, data: data),
  );
}

Future<void> deleteMoment(
  BuildContext context,
  String familyId,
  String id,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const WordSafeText('이 마음 기록을 삭제할까요?'),
      content: const WordSafeText('삭제한 글은 가족 피드에서 사라져요.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const WordSafeText('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const WordSafeText('삭제'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await MomentService.instance.deleteMoment(familyId: familyId, momentId: id);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: WordSafeText('삭제하지 못했어요. 연결과 수정 권한을 확인해주세요.')),
      );
    }
  }
}

class _MomentEditor extends StatefulWidget {
  const _MomentEditor({
    required this.familyId,
    required this.id,
    required this.data,
  });
  final String familyId, id;
  final Map<String, dynamic> data;
  @override
  State<_MomentEditor> createState() => _MomentEditorState();
}

class _MomentEditorState extends State<_MomentEditor> {
  late final _mood = TextEditingController(
    text: widget.data['mood'] as String? ?? '',
  );
  late final _body = TextEditingController(
    text: widget.data['body'] as String? ?? '',
  );
  bool _busy = false;
  String? _error;
  Future<void> _save() async {
    if (_busy) return;
    if (_body.text.trim().isEmpty) {
      setState(() => _error = '내용을 입력해주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await MomentService.instance.updateMoment(
        familyId: widget.familyId,
        momentId: widget.id,
        mood: _mood.text,
        body: _body.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = '저장하지 못했어요. 연결과 수정 권한을 확인해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _mood.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        22,
        8,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WordSafeText(
            '마음 기록 수정',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mood,
            enabled: !_busy,
            maxLength: 200,
            decoration: const InputDecoration(labelText: '오늘의 기분'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            enabled: !_busy,
            maxLength: 5000,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: '가족과 나눌 이야기'),
          ),
          if (_error != null)
            WordSafeText(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: WordSafeText(_busy ? '저장 중…' : '저장하기'),
            ),
          ),
        ],
      ),
    ),
  );
}
