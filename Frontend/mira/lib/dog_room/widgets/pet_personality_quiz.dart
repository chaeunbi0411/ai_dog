import 'package:flutter/material.dart';
import '../models/pet_personality.dart';
import '../../widgets/word_wrap_text.dart';

class PetPersonalityQuiz extends StatefulWidget {
  const PetPersonalityQuiz({super.key, this.initial});
  final PetPersonality? initial;
  @override
  State<PetPersonalityQuiz> createState() => _PetPersonalityQuizState();
}

class _PetPersonalityQuizState extends State<PetPersonalityQuiz> {
  late final List<int> _answers =
      widget.initial?.answers.toList() ?? List.filled(4, -1);
  int _step = 0;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WordSafeText(
            '우리 아이 알아보기 · ${_step + 1} / 4',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const WordWrapText('평소 모습을 떠올려 골라주세요. 답이 대화 말투에 반영돼요.'),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (_step + 1) / 4,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 24),
          WordWrapText(
            PetPersonality.questions[_step],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _answers[_step] == i
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    padding: const EdgeInsets.all(18),
                  ),
                  onPressed: () => setState(() => _answers[_step] = i),
                  child: WordWrapText(PetPersonality.options[_step][i]),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_step > 0)
                TextButton(
                  onPressed: () => setState(() => _step--),
                  child: const WordSafeText('이전'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _answers[_step] < 0
                    ? null
                    : () {
                        if (_step < 3) {
                          setState(() => _step++);
                        } else {
                          Navigator.pop(
                            context,
                            PetPersonality(_answers.toList()),
                          );
                        }
                      },
                child: WordSafeText(_step == 3 ? '성격 결과 적용' : '다음'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
