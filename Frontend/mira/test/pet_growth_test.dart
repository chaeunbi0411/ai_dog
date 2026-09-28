import 'package:flutter_test/flutter_test.dart';
import 'package:mira/dog_room/controllers/dog_controller.dart';
import 'package:mira/dog_room/models/dog_state.dart';
import 'package:mira/dog_room/services/dog_save_service.dart';

class MemorySave implements DogSaveService {
  MemorySave(this.state);
  DogState state;
  @override
  Future<DogState?> load() async => state;
  @override
  Future<void> save(DogState value) async => state = value;
}

void main() {
  DogState at(int xp) => DogState(experience: xp, lastUpdated: DateTime.now());
  test('document growth boundaries and unlocks', () {
    for (final row in [
      (1000, 5),
      (1001, 6),
      (4000, 15),
      (4001, 16),
      (9000, 30),
      (9001, 31),
    ]) {
      expect(at(row.$1).level, row.$2);
    }
    expect(at(1000).wardrobeUnlocked, false);
    expect(at(1001).wardrobeUnlocked, true);
    expect(at(4000).roomThemesUnlocked, false);
    expect(at(4001).roomThemesUnlocked, true);
    expect(at(9001).rewardCount(AdultReward.hat), 0);
    expect(at(9501).rewardCount(AdultReward.hat), 1);
    expect(at(11501).rewardCount(AdultReward.hat), 2);
    for (final level in [50, 77, 99, 120]) {
      expect(at(9001 + (level - 31) * 500).familyTitle, isNotNull);
    }
  });
  test(
    'locked equipment rejected and unlocked choices survive reload',
    () async {
      final save = MemorySave(at(0));
      final dog = DogController(save);
      await dog.initialize();
      await dog.customize(accessory: 'crown', roomTheme: 'spring');
      expect(dog.state.accessory, 'none');
      expect(dog.state.roomTheme, 'default');
      dog.dispose();
      save.state = at(10501);
      final grown = DogController(save);
      await grown.initialize();
      await grown.customize(accessory: 'crown', roomTheme: 'starlight');
      final restored = DogState.fromJson(save.state.toJson());
      expect(restored.accessory, 'crown');
      expect(restored.roomTheme, 'starlight');
      expect(restored.level, 34);
      grown.dispose();
    },
  );
}
