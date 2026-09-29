import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:mira/dog_room/models/character_animation_set.dart';
import 'package:mira/dog_room/models/care_motion.dart';
import 'package:mira/dog_room/models/dog_state.dart';
import 'package:mira/dog_room/controllers/dog_controller.dart';
import 'package:mira/dog_room/services/character_save_service.dart';
import 'package:mira/dog_room/services/dog_save_service.dart';
import 'package:mira/dog_room/screens/dog_room_screen.dart';
import 'package:mira/dog_room/widgets/animated_character.dart';

class _Storage implements DogSaveService {
  DogState? value;
  @override
  Future<DogState?> load() async => value;
  @override
  Future<void> save(DogState state) async => value = state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = File('assets/dog/baby_idle.png').readAsBytesSync();
  CharacterAnimationSet character() => CharacterAnimationSet(
    preview: png,
    clips: {
      for (final name in CharacterAnimationSet.requiredClips)
        name: CharacterClip(frames: [png, png], fps: 10,
          loop: !name.endsWith('_enter') && !name.endsWith('_exit')),
    },
  );
  setUp(() => SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty());

  test('preview-only saves do not replace the default; animation saves are scoped', () async {
    final save = CharacterSaveService.instance;
    await save.save(png);
    expect(await save.loadAnimations('family-a'), isNull);
    await save.saveAnimations('family-a', character());
    expect((await save.loadAnimations('family-a'))!.preview, png);
    expect(await save.loadAnimations('family-b'), isNull);
  });

  test('missing clips and corrupt cache cannot activate a partial character', () async {
    final json = character().toJson();
    (json['clips'] as Map).remove('sleep_exit');
    expect(() => CharacterAnimationSet.fromJson(json), throwsFormatException);
    await SharedPreferencesAsync().setString('pet_animations_v1_family', jsonEncode(json));
    expect(await CharacterSaveService.instance.loadAnimations('family'), isNull);
  });

  test('compact storage shares repeated PNGs and restores every clip', () {
    final json = character().toJson();
    expect(json['images'], hasLength(1));
    final restored = CharacterAnimationSet.fromJson(json);
    expect(restored.clips.keys, containsAll(CharacterAnimationSet.requiredClips));
    expect(identical(restored.clips['idle']!.frames.first,
      restored.clips['sleep_exit']!.frames.first), isTrue);
  });

  testWidgets('no generated set uses the existing asset renderer', (tester) async {
    final dog = DogController(_Storage());
    await dog.initialize();
    await tester.pumpWidget(MaterialApp(home: DogRoomScreen(controller: dog)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AnimatedCharacter), findsNothing);
    expect(find.byWidgetPredicate((w) => w is Image && w.image is AssetImage &&
      (w.image as AssetImage).assetName == 'assets/dog/baby_idle.png'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    dog.dispose();
  });

  for (final action in CareAction.values) {
    testWidgets('${action.name} moves, acts, returns and completes exactly once', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await CharacterSaveService.instance.saveAnimations('local', character());
      final dog = DogController(_Storage());
      await dog.initialize();
      final completed = <CareAction>[];
      await tester.pumpWidget(MaterialApp(home: DogRoomScreen(
        controller: dog, onCareAction: completed.add)));
      for (var i = 0; i < 20 && find.byType(AnimatedCharacter).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(AnimatedCharacter), findsOneWidget);
      final origin = tester.widget<AnimatedPositioned>(find.byKey(const ValueKey('dog-position')));
      final label = switch (action) {
        CareAction.feed => '밥 주기', CareAction.wash => '목욕',
        CareAction.play => '놀기', CareAction.sleep => '재우기',
      };
      await tester.tap(find.text(label));
      await tester.pump();
      expect(find.text(careSpeech(action, CarePhase.approaching)), findsOneWidget);
      expect(completed, isEmpty);
      final seen = <String>{};
      var returned = false;
      for (var i = 0; i < 240 && completed.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        seen.add(tester.widget<AnimatedCharacter>(find.byType(AnimatedCharacter)).clip);
        returned |= find.text(careSpeech(action, CarePhase.returning)).evaluate().isNotEmpty;
      }
      expect(seen, containsAll(['walk', '${action.name}_enter', action.name, '${action.name}_exit']));
      expect(returned, isTrue);
      expect(completed, [action]);
      final destination = tester.widget<AnimatedPositioned>(find.byKey(const ValueKey('dog-position')));
      expect(destination.left, origin.left);
      expect(destination.top, origin.top);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      dog.dispose();
    });
  }
}
