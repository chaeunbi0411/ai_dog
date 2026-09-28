import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira/dog_room/models/pet_personality.dart';
import 'package:mira/dog_room/widgets/pet_personality_quiz.dart';

void main() {
  test(
    'Personality persists all four independent answers and rejects corrupt data',
    () {
      const profile = PetPersonality([0, 1, 2, 0]);
      expect(PetPersonality.fromJson(profile.toJson())!.answers, [0, 1, 2, 0]);
      expect(profile.labels.length, 4);
      expect(
        PetPersonality.fromJson({
          'answers': [0, 1],
        }),
        isNull,
      );
      expect(
        PetPersonality.fromJson({
          'answers': [0, 1, 2, 3],
        }),
        isNull,
      );
    },
  );
  testWidgets('Quiz requires each answer, supports back, and returns result', (
    tester,
  ) async {
    PetPersonality? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<PetPersonality>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const PetPersonalityQuiz(),
                );
              },
              child: const Text('start'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '다음'))
          .onPressed,
      isNull,
    );
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.bySemanticsLabel(PetPersonality.options[i][i % 3]));
      await tester.pump();
      await tester.tap(find.text(i == 3 ? '성격 결과 적용' : '다음'));
      await tester.pumpAndSettle();
    }
    expect(result!.answers, [0, 1, 2, 0]);
  });
}
