import 'package:flutter/material.dart';

class HighlightedText extends StatelessWidget {
  final String text;

  const HighlightedText({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    // highlight text enclosed in #s
    List<Widget> children = [];
    int start = 0;
    int end = 0;
    while (end < text.length) {
      if (text[end] == '#') {
        if (end > start) {
          children.add(Text(text.substring(start, end)));
        }
        start = end + 1;
        end = start;
        while (end < text.length && text[end] != '#') {
          end++;
        }
        if (end < text.length) {
          children.add(Text(
            text.substring(start, end),
            style: TextStyle(fontWeight: FontWeight.bold),
          ));
          start = end + 1;
          end = start;
        }
      } else {
        end++;
      }
    }
    if (end > start) {
      children.add(Text(text.substring(start, end)));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
