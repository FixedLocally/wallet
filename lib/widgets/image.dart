import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils/utils.dart';
import 'svg.dart';

class MultiImage extends StatefulWidget {
  final String image;
  final double? size;
  final double? borderRadius;
  final bool cleanSvg;

  const MultiImage({
    Key? key,
    required this.image,
    this.size,
    this.borderRadius,
    this.cleanSvg = true,
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
        cleanSvg: widget.cleanSvg,
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
      borderRadius: BorderRadius.circular(widget.borderRadius ?? ((widget.size ?? 0) / 2)),
      child: _builder(context),
    );
  }
}

class Logo extends StatefulWidget {
  final List<String> urls;
  final double width;
  final double height;

  const Logo({
    Key? key,
    required this.urls,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  State<Logo> createState() => _LogoState();
}

class _LogoState extends State<Logo> {
  FileInfo? _fileInfo;
  bool _exhausted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    for (String url in widget.urls) {
      FileInfo? fileInfo;
      try {
        fileInfo = await DefaultCacheManager().getFileFromCache(url);
        fileInfo ??= await DefaultCacheManager().downloadFile(url);
      } catch (_) {}
      if (fileInfo != null) {
        setState(() {
          _fileInfo = fileInfo;
        });
        return;
      }
    }
    setState(() {
      _exhausted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // try the images one by one
    if (_fileInfo != null) {
      return Image.file(
        _fileInfo!.file,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
      );
    } else {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: _exhausted ? Icon(Icons.language, size: min(widget.width, widget.height)) : CircularProgressIndicator(),
        ),
      );
    }
  }
}

class KeybaseThumbnail extends StatefulWidget {
  final String username;
  final double size;

  const KeybaseThumbnail({Key? key, required this.username, required this.size}) : super(key: key);

  @override
  State<KeybaseThumbnail> createState() => _KeybaseThumbnailState();
}

class _KeybaseThumbnailState extends State<KeybaseThumbnail> {
  String? _url;

  @override
  void initState() {
    super.initState();
    Utils.httpGet("https://keybase.io/_/api/1.0/user/pic_url.json?username=${widget.username}").then((value) {
      setState(() {
        _url = jsonDecode(value)["pic_url"];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.size / 2),
        child: CachedNetworkImage(
          imageUrl: _url!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
        ),
      );
    }
  }
}

