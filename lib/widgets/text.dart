import 'package:flutter/material.dart';

class HighlightedText extends StatelessWidget {
  final String text;
  final TextStyle highlightStyle;
  final TextStyle normalStyle;
  final TextAlign textAlign;

  const HighlightedText({
    super.key,
    required this.text,
    this.highlightStyle = const TextStyle(
      fontWeight: FontWeight.bold,
    ),
    this.normalStyle = const TextStyle(),
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    // highlight text enclosed in #s
    List<TextSpan> children = [];
    int start = 0;
    int end = 0;
    while (end < text.length) {
      if (text[end] == '#') {
        if (end > start) {
          children.add(TextSpan(text: text.substring(start, end)));
        }
        start = end + 1;
        end = start;
        while (end < text.length && text[end] != '#') {
          end++;
        }
        if (end < text.length) {
          children.add(TextSpan(
            text: text.substring(start, end),
            style: highlightStyle,
          ));
          start = end + 1;
          end = start;
        }
      } else {
        end++;
      }
    }
    if (end > start) {
      children.add(TextSpan(text: text.substring(start, end), style: normalStyle));
    }
    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: (Theme.of(context).textTheme.bodyText2 ?? TextStyle()).merge(normalStyle),
        children: children,
      ),
    );
  }
}
