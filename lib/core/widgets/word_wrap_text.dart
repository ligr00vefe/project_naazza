import 'package:flutter/material.dart';

/// Korean equivalent of CSS word-break: keep-all. Original paragraphs/semantics
/// are preserved; a single oversized token is ellipsized rather than split.
class WordWrapText extends StatelessWidget {
  const WordWrapText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final effective =
        (Theme.of(context).textTheme.bodyMedium ??
                DefaultTextStyle.of(context).style)
            .merge(style);
    final space = TextPainter(
      text: TextSpan(text: ' ', style: effective),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final spacing = space.width;
    space.dispose();
    return LayoutBuilder(
      builder: (context, constraints) {
        final measure = TextPainter(
          text: TextSpan(text: text, style: effective),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final fits =
            !text.contains('\n') && measure.width <= constraints.maxWidth;
        measure.dispose();
        if (fits) return Text(text, style: effective, softWrap: false);
        return Semantics(
          label: text,
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final paragraph in text.split('\n'))
                  paragraph.trim().isEmpty
                      ? SizedBox(height: (effective.fontSize ?? 13) * .6)
                      : Wrap(
                          spacing: spacing,
                          runSpacing: 1,
                          children: [
                            for (final word in paragraph.trim().split(
                              RegExp(r'\s+'),
                            ))
                              Text(
                                word,
                                style: effective,
                                softWrap: false,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
              ],
            ),
          ),
        );
      },
    );
  }
}
