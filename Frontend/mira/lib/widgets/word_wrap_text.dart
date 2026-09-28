import 'package:flutter/material.dart';

/// Keeps Korean words together while honoring explicit paragraph breaks.
class WordWrapText extends StatelessWidget {
  const WordWrapText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final space = TextPainter(
      text: TextSpan(text: ' ', style: effectiveStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final spacing = space.width;
    space.dispose();
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in text.replaceAll('\r\n', '\n').split('\n'))
            if (line.trim().isEmpty)
              Text('', style: effectiveStyle)
            else
              Wrap(
                spacing: spacing,
                children: [
                  for (final word
                      in line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty))
                    Text(word, softWrap: true, style: effectiveStyle),
                ],
              ),
        ],
      ),
    );
  }
}
