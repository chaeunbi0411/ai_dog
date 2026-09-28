import '../../widgets/word_wrap_text.dart';
import 'package:flutter/material.dart';

import '../controllers/dog_controller.dart';

class CareActionBar extends StatelessWidget {
  const CareActionBar({super.key, required this.onAction, this.enabled = true});

  final ValueChanged<CareAction> onAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Row(
            children: [
              _CareButton(
                icon: Icons.restaurant,
                label: '밥 주기',
                onPressed: enabled ? () => onAction(CareAction.feed) : null,
              ),
              _CareButton(
                icon: Icons.bathtub,
                label: '목욕',
                onPressed: enabled ? () => onAction(CareAction.wash) : null,
              ),
              _CareButton(
                icon: Icons.sports_baseball,
                label: '놀기',
                onPressed: enabled ? () => onAction(CareAction.play) : null,
              ),
              _CareButton(
                icon: Icons.bedtime,
                label: '재우기',
                onPressed: enabled ? () => onAction(CareAction.sleep) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CareButton extends StatelessWidget {
  const _CareButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = switch (icon) {
      Icons.restaurant => const Color(0xFFB9824E),
      Icons.bathtub => const Color(0xFF659DAC),
      Icons.sports_baseball => const Color(0xFFC77F88),
      _ => const Color(0xFF9588B7),
    };
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: color,
            backgroundColor: color.withValues(alpha: .10),
            disabledBackgroundColor: const Color(0xFFF0EBE5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon == Icons.sports_baseball)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sports_baseball_outlined,
                    size: 25,
                    color: color,
                  ),
                )
              else
                Image.asset(
                  switch (icon) {
                    Icons.restaurant => 'assets/furniture/food_bowl.png',
                    Icons.bathtub => 'assets/furniture/bathtub.png',
                    _ => 'assets/furniture/bed.png',
                  },
                  width: 40,
                  height: 32,
                ),
              const SizedBox(height: 7),
              WordSafeText(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
