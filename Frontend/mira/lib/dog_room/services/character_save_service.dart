import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/character_animation_set.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Activate a complete set atomically; incomplete generations never replace it.
class CharacterSaveService extends ChangeNotifier {
  CharacterSaveService._();
  static final instance = CharacterSaveService._();

  static const _key = 'pet_character_v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<CharacterAnimationSet?> loadAnimations(String scope) async {
    final encoded = await _preferences.getString('pet_animations_v1_$scope');
    if (encoded == null) return null;
    try {
      return CharacterAnimationSet.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    } catch (_) {
      return null; // Keep the bundled default if a cache is incomplete/corrupt.
    }
  }

  Future<void> saveAnimations(String scope, CharacterAnimationSet character) async {
    await _preferences.setString('pet_animations_v1_$scope', jsonEncode(character.toJson()));
    notifyListeners();
    await save(character.preview);
  }

  Future<Uint8List?> load() async {
    final encoded = await _preferences.getString(_key);
    if (encoded == null) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(Uint8List bytes) =>
      _preferences.setString(_key, base64Encode(bytes));

  Future<void> clear() => _preferences.remove(_key);
}
