import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira/main.dart';
import 'package:mira/privacy/privacy_screen.dart';
import 'package:mira/dog_room/controllers/dog_controller.dart';
import 'package:mira/dog_room/models/care_reminder.dart';
import 'package:mira/dog_room/models/dog_state.dart';
import 'package:mira/dog_room/screens/dog_room_screen.dart';
import 'package:mira/dog_room/services/dog_save_service.dart';
import 'package:mira/widgets/word_wrap_text.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _MemorySave implements DogSaveService {
  @override
  Future<DogState?> load() async => null;
  @override
  Future<void> save(DogState state) async {}
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    font.addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'));
    await font.load();
  });
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  for (final size in [
    const Size(320, 640),
    const Size(360, 740),
    const Size(390, 844),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 1.4, 2.0]) {
      testWidgets('screens fit ${size.width}x${size.height} at $scale text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        textScaleNotifier.value = scale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          textScaleNotifier.value = 1;
        });
        final dog = DogController(_MemorySave());
        await dog.initialize();
        for (final page in <Widget>[
          AuthScreen(onDone: () {}),
          ProfileSetup(onDone: () {}),
          PetSetup(onDone: () {}),
          PrivacyScreen(onDone: () {}),
          DogRoomScreen(
            controller: dog,
            petName: '우리 가족의 아주 사랑스러운 강아지',
            viewerAddress: '우리집에서제일멋진누나',
            careReminders: [
              CareReminder('other', '아주 긴 이름의 가족', '🍚 밥 주기', 'today'),
            ],
            onTalk: () {},
          ),
          const MainShell(),
        ]) {
          await tester.pumpWidget(MiraApp(home: page));
          await tester.pump(const Duration(milliseconds: 200));
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.runtimeType} $size $scale',
          );
          if (page is DogRoomScreen) {
            await tester.pump(const Duration(seconds: 6));
            final toggle = find.byKey(const ValueKey('dog-speech-toggle'));
            await tester.ensureVisible(toggle);
            await tester.pump();
            await tester.tap(toggle);
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: 'speech $size $scale',
            );
          }
        }
        for (final label in ['펫', '가족', '사진첩', 'MIRA', '설정', '홈']) {
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(label),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull, reason: '$label $size $scale');
        }
        await tester.pumpWidget(const SizedBox());
        dog.dispose();
      });
    }
  }

  testWidgets('system font size and app font preference both apply', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    textScaleNotifier.value = 1.4;
    addTearDown(() {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      textScaleNotifier.value = 1;
    });
    double? renderedSize;
    await tester.pumpWidget(
      MiraApp(
        home: Builder(
          builder: (context) {
            renderedSize = MediaQuery.textScalerOf(context).scale(20);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(renderedSize, closeTo(42, .01));
  });

  testWidgets('Korean words stay on one line and oversized words can wrap', (
    tester,
  ) async {
    const sentence = '반려견에게 듣고 싶은 호칭을 지정해주세요.';
    for (final width in [120.0, 180.0, 300.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: const WordSafeText(
                sentence,
                style: TextStyle(fontFamily: 'Pretendard', fontSize: 18),
              ),
            ),
          ),
        ),
      );
      for (final word in sentence.split(' ')) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(word));
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: word.length),
        );
        expect(boxes.map((b) => b.top).toSet(), hasLength(1));
        expect(paragraph.size.width, lessThanOrEqualTo(width));
      }
      expect(find.text(sentence), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
