import 'package:flutter/material.dart';

import '../widgets/image.dart';

class ImageRoute extends StatefulWidget {
  final String image;

  const ImageRoute({Key? key, required this.image}) : super(key: key);

  @override
  State<ImageRoute> createState() => _ImageRouteState();
}

class _ImageRouteState extends State<ImageRoute> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image'),
      ),
      body: InteractiveViewer(
        minScale: 0.01,
        maxScale: 100,
        child: Center(
          child: MultiImage(
            image: widget.image,
            // size: mq.size.width,
            borderRadius: 0,
          ),
        ),
      ),
    );
  }
}
