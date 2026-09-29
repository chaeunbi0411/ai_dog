import 'dart:async';
import 'package:flutter/material.dart';
import '../models/character_animation_set.dart';

class AnimatedCharacter extends StatefulWidget {
  const AnimatedCharacter({super.key, required this.character, required this.clip,
    required this.facingRight});
  final CharacterAnimationSet character;
  final String clip;
  final bool facingRight;

  @override
  State<AnimatedCharacter> createState() => _AnimatedCharacterState();
}

class _AnimatedCharacterState extends State<AnimatedCharacter> {
  Timer? _timer;
  int _frame = 0;
  CharacterClip get _clip => widget.character.clips[widget.clip] ??
      widget.character.clips['idle']!;

  @override
  void initState() { super.initState(); _restart(); }

  @override
  void didUpdateWidget(covariant AnimatedCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip != widget.clip || oldWidget.character != widget.character) _restart();
  }

  void _restart() {
    _timer?.cancel();
    _frame = 0;
    _timer = Timer.periodic(Duration(microseconds: 1000000 ~/ _clip.fps), (timer) {
      if (_frame + 1 >= _clip.frames.length && !_clip.loop) {
        timer.cancel();
        return;
      }
      setState(() => _frame = (_frame + 1) % _clip.frames.length);
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Transform.flip(
    flipX: !widget.facingRight,
    child: Image.memory(_clip.frames[_frame], width: 140, height: 140,
      fit: BoxFit.contain, gaplessPlayback: true,
      errorBuilder: (_, error, stack) => Image.memory(widget.character.preview,
        width: 140, height: 140, fit: BoxFit.contain)),
  );
}
