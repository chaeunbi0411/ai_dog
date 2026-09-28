import '../../widgets/word_wrap_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/dog_state.dart';

class DogStatusPanel extends StatelessWidget {
  const DogStatusPanel({super.key, required this.state, this.petName = '강아지'});
  final DogState state;
  final String petName;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.paw, color: Color(0xFF315E50), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: WordSafeText(
                '$petName의 방',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: WordSafeText(
            'Lv.${state.level} · ${state.stage.label}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF68766D),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: state.levelProgress, minHeight: 4),
        const SizedBox(height: 4),
        WordSafeText(
          '다음 레벨까지 ${state.experienceToNextLevel} XP',
          style: const TextStyle(fontSize: 11, color: Color(0xFF68766D)),
        ),
        if (state.familyTitle != null)
          WordSafeText(
            state.familyTitle!,
            style: const TextStyle(fontSize: 12),
          ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final needs = [
              _Need('배부름', state.hunger, const Color(0xFFB8874D)),
              _Need('청결', state.cleanliness, const Color(0xFF5E92A0)),
              _Need('행복', state.happiness, const Color(0xFFBF7779)),
              _Need('체력', state.energy, const Color(0xFF8B82AC)),
            ];
            final columns =
                constraints.maxWidth <
                    MediaQuery.textScalerOf(context).scale(12) * 26
                ? 2
                : 4;
            return Column(
              children: [
                for (var i = 0; i < needs.length; i += columns)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                    child: Row(
                      children: [
                        for (var j = i; j < i + columns; j++) ...[
                          if (j > i) const SizedBox(width: 12),
                          needs[j],
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _Need extends StatelessWidget {
  const _Need(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: '$label $value퍼센트, ${value < 30 ? '돌봄이 필요해요' : '좋아요'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WordSafeText(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF68766D)),
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: value / 100,
            minHeight: 5,
            color: color,
            backgroundColor: color.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    ),
  );
}
