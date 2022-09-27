import 'package:flutter/material.dart';

import '../generated/l10n.dart';
import '../widgets/image.dart';

class ImageRoute extends StatefulWidget {
  final String image;
  final String? heroTag;

  const ImageRoute({
    Key? key,
    required this.image,
    this.heroTag,
  }) : super(key: key);

  @override
  State<ImageRoute> createState() => _ImageRouteState();
}

class _ImageRouteState extends State<ImageRoute> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.image),
      ),
      body: InteractiveViewer(
        minScale: 0.01,
        maxScale: 100,
        child: Center(
          child: MultiImage(
            heroTag: widget.heroTag,
            image: widget.image,
            // size: mq.size.width,
            borderRadius: 0,
          ),
        ),
      ),
    );
  }
}
