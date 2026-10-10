import 'package:flutter/material.dart';

/// 공백에서만 줄을 바꾸며, 한 단어를 여러 줄로 나누지 않는다.
class WordWrapText extends StatelessWidget {
  const WordWrapText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Semantics(
    label: text,
    child: ExcludeSemantics(
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: [
          for (final word in text.split(RegExp(r'\s+')))
            Text(word, style: style, softWrap: false),
        ],
      ),
    ),
  );
}
