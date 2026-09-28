import 'package:flutter/material.dart';
import '../../services/ai_server_service.dart';
import '../../services/pet_service.dart';
import '../models/pet_personality.dart';
import '../../widgets/word_wrap_text.dart';

class PetChatSheet extends StatefulWidget {
  const PetChatSheet({super.key, required this.careContext, this.familyId});
  final String? familyId;
  final String Function() careContext;
  @override
  State<PetChatSheet> createState() => _PetChatSheetState();
}

class _PetChatSheetState extends State<PetChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _history = <Map<String, String>>[];
  bool _busy = false;
  String? _error;

  Future<void> _send() async {
    final message = _input.text.trim();
    if (_busy || message.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pet = widget.familyId == null
          ? null
          : await PetService.instance.fetchPet(widget.familyId!);
      if (!mounted) return;
      final personality = PetPersonality.fromJson(pet?['personalityProfile']);
      final reply = await AiServerService.instance.chatWithPet(
        petName: pet?['name'] as String? ?? '',
        personalityAnswers: personality?.answers ?? const [],
        message: message,
        careContext: widget.careContext(),
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
        _input.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } on AiServerException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '강아지 정보를 불러오지 못했어요. 다시 보내주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .6,
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '강아지와 이야기',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: '닫기',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text('오늘의 돌봄 이야기를 해보자!'),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final turn = _history[index];
                  final mine = turn['role'] == 'user';
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Card(
                      color: mine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: WordWrapText(turn['text']!),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(8),
                child: WordWrapText('강아지가 답변을 생각하고 있어요. 잠시만 기다려주세요.'),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: !_busy,
                    maxLength: 500,
                    decoration: const InputDecoration(hintText: '강아지에게 말 걸기'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _send,
                  tooltip: '보내기',
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
