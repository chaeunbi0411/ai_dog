import 'package:flutter/material.dart';

/// Shared word-based wrapping with the original Text data and semantics.
class WordSafeText extends Text {
  const WordSafeText(
    super.data, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!RegExp(r'\s').hasMatch(data!) ||
        softWrap == false ||
        maxLines != null) {
      return super.build(context);
    }
    return WordWrapText(
      data!,
      style: style,
      textAlign:
          textAlign ??
          DefaultTextStyle.of(context).textAlign ??
          TextAlign.start,
    );
  }
}

/// Keeps Korean words together while honoring explicit paragraph breaks.
class WordWrapText extends StatelessWidget {
  const WordWrapText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
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
        crossAxisAlignment: textAlign == TextAlign.center
            ? CrossAxisAlignment.center
            : textAlign == TextAlign.end || textAlign == TextAlign.right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          for (final line in text.replaceAll('\r\n', '\n').split('\n'))
            if (line.trim().isEmpty)
              Text('', style: effectiveStyle)
            else
              Wrap(
                spacing: spacing,
                alignment: textAlign == TextAlign.center
                    ? WrapAlignment.center
                    : textAlign == TextAlign.end || textAlign == TextAlign.right
                    ? WrapAlignment.end
                    : WrapAlignment.start,
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
