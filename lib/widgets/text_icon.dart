import 'package:flutter/material.dart';

class TextIcon extends StatelessWidget {
  final String text;
  final double? radius;

  const TextIcon({Key? key, required this.text, this.radius}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.primary,
        child: Text(text.split(" ").map((x) => x.substring(0, 1).toUpperCase()).take(2).join(""), style: TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }
}
