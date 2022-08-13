import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'svg.dart';

class MultiImage extends StatefulWidget {
  final String image;
  final double size;
  final double? borderRadius;

  const MultiImage({
    Key? key,
    required this.image,
    required this.size,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<MultiImage> createState() => _MultiImageState();
}

class _MultiImageState extends State<MultiImage> {
  late WidgetBuilder _builder;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    Uri? uri = Uri.tryParse(widget.image);
    if (uri?.data?.mimeType.startsWith("image/svg") == true) {
      _builder = (_) => StringSvg(
        svg: uri!.data!.contentAsString(),
        width: widget.size,
        height: widget.size,
      );
    } else if (widget.image.endsWith(".svg")) {
      _builder = (_) => NetworkSvg(
        url: widget.image,
        width: widget.size,
        height: widget.size,
      );
    } else {
      _builder = (_) => CachedNetworkImage(
        imageUrl: widget.image,
        height: widget.size,
        width: widget.size,
        fit: BoxFit.cover,
      );
    }
  }

  @override
  void didUpdateWidget(MultiImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius ?? (widget.size / 2)),
      child: _builder(context),
    );
  }
}
