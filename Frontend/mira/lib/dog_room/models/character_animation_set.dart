import 'dart:convert';
import 'dart:typed_data';

/// One generated character. Only [preview] is shown during setup.
class CharacterAnimationSet {
  CharacterAnimationSet({required this.preview, required this.clips});

  static const requiredClips = [
    'idle', 'walk', 'greet',
    'feed_enter', 'feed', 'feed_exit',
    'wash_enter', 'wash', 'wash_exit',
    'play_enter', 'play', 'play_exit',
    'sleep_enter', 'sleep', 'sleep_exit',
  ];
  final Uint8List preview;
  final Map<String, CharacterClip> clips;

  factory CharacterAnimationSet.fromJson(Map<String, dynamic> json) {
    if (![1, 2].contains(json['version']) || json['clips'] is! Map) {
      throw const FormatException('Unsupported character animations');
    }
    final raw = Map<String, dynamic>.from(json['clips'] as Map);
    final clips = <String, CharacterClip>{};
    final decoded = <String, Uint8List>{};
    Uint8List frame(dynamic value) {
      if (json['version'] == 2) {
        final images = json['images'];
        if (images is! List || value is! int || value < 0 || value >= images.length) {
          throw const FormatException('Invalid frame reference');
        }
        value = images[value];
      }
      if (value is! String) throw const FormatException('Missing PNG');
      return decoded.putIfAbsent(value, () => decodePng(value));
    }
    for (final name in requiredClips) {
      if (raw[name] is! Map) throw FormatException('Missing animation: $name');
      clips[name] = CharacterClip.fromJson(Map<String, dynamic>.from(raw[name] as Map), decode: frame);
    }
    return CharacterAnimationSet(preview: decodePng(json['preview']), clips: clips);
  }

  // Enter/exit clips share frames. Persist each PNG once to fit web storage.
  Map<String, dynamic> toJson() {
    final images = <String>[];
    final indices = <String, int>{};
    final encodedClips = <String, dynamic>{};
    for (final entry in clips.entries) {
      final frames = <int>[];
      for (final bytes in entry.value.frames) {
        final encoded = base64Encode(bytes);
        frames.add(indices.putIfAbsent(encoded, () {
          images.add(encoded);
          return images.length - 1;
        }));
      }
      encodedClips[entry.key] = {
        'frames': frames, 'fps': entry.value.fps, 'loop': entry.value.loop,
      };
    }
    return {'version': 2, 'preview': base64Encode(preview),
      'images': images, 'clips': encodedClips};
  }

  static Uint8List decodePng(dynamic encoded) {
    if (encoded is! String) throw const FormatException('Missing PNG');
    final bytes = base64Decode(encoded);
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 24 ||
        !List.generate(8, (i) => bytes[i] == signature[i]).every((v) => v)) {
      throw const FormatException('Invalid PNG');
    }
    return bytes;
  }
}

class CharacterClip {
  CharacterClip({required this.frames, required this.fps, required this.loop});
  final List<Uint8List> frames;
  final int fps;
  final bool loop;
  Duration get duration => Duration(microseconds: frames.length * 1000000 ~/ fps);

  factory CharacterClip.fromJson(Map<String, dynamic> json, {Uint8List Function(dynamic)? decode}) {
    final frames = json['frames'];
    final fps = json['fps'];
    if (frames is! List || frames.isEmpty || frames.length > 64 ||
        fps is! int || fps < 1 || fps > 30 || json['loop'] is! bool) {
      throw const FormatException('Invalid animation');
    }
    return CharacterClip(frames: frames.map(decode ?? CharacterAnimationSet.decodePng).toList(),
      fps: fps, loop: json['loop'] as bool);
  }

  Map<String, dynamic> toJson() => {
    'frames': frames.map(base64Encode).toList(), 'fps': fps, 'loop': loop,
  };
}
