import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira/main.dart';
import 'package:mira/widgets/word_wrap_text.dart';
import 'package:mira/dog_room/widgets/pet_chat_sheet.dart';
import 'package:mira/dog_room/widgets/pet_personality_quiz.dart';

void main() {
  testWidgets('Words wrap intact, long words fit, and blank lines remain', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: WordWrapText(
                'hello world\n\nverylongwordwithoutanyspacesatall',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('world')).dy,
      greaterThan(tester.getTopLeft(find.text('hello')).dy),
    );
    expect(find.text(''), findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('verylongwordwithoutanyspacesatall'),
    );
    expect(paragraph.size.width, lessThanOrEqualTo(120));
    expect(paragraph.size.height, greaterThan(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cards and section headings fit at 320px with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Section('가족 모두의 오늘 돌봄 현황', '이번 주 100 / 100 완료'),
                    DiaryCard(
                      name: '아주 긴 이름을 사용하는 가족 구성원',
                      mood: '오늘은 즐겁고 행복한 하루였어요',
                      body: '가족과 함께 나눈 이야기예요.',
                      likes: 1,
                      comments: 2,
                    ),
                    CareLine('이름이 아주 긴 가족 구성원', '오늘은 강아지에게 밥 주기 담당이에요'),
                    QuestCard(
                      icon: '🍽️',
                      title: '가족 모두 이번 주 이야기 하나씩',
                      detail: '이번 주 마음을 남기고 가족과 이야기 나눠요',
                      progress: .5,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pet chat fits a small screen with keyboard visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            viewInsets: EdgeInsets.only(bottom: 280),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: PetChatSheet(careContext: () => ''),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Personality quiz remains scrollable with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(body: PetPersonalityQuiz()),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
