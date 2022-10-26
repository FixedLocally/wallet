import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../rpc/key_manager.dart';
import '../utils/utils.dart';
import 'svg.dart';

class MultiImage extends StatefulWidget {
  final String? image;
  final String? heroTag;
  final double? size;
  final double? borderRadius;
  final bool cleanSvg;

  const MultiImage({
    Key? key,
    required this.image,
    this.heroTag,
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
    if (widget.image == null) {
      _builder = (_) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(child: Icon(Icons.image, size: (widget.size ?? 48) / 2)),
      );
      return;
    }
    String image = widget.image!;
    if (image.startsWith("/")) {
      image = "file://$image";
    }
    Uri? uri = Uri.tryParse(image);
    if (uri?.data?.mimeType.startsWith("image/svg") == true) {
      // data svg
      _builder = (_) => StringSvg(
        svg: uri!.data!.contentAsString(),
        width: widget.size,
        height: widget.size,
      );
    } else if (image.endsWith(".svg")) {
      // other svg
      _builder = (_) => NetworkSvg(
        url: image,
        width: widget.size,
        height: widget.size,
        cleanSvg: widget.cleanSvg,
      );
    } else if (uri?.scheme == "file") {
      _builder = (_) => Image.file(
        File(uri!.path),
        height: widget.size,
        width: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.language, size: (widget.size ?? 48)),
      );
    } else if (uri != null) {
      _builder = (_) => CachedNetworkImage(
        imageUrl: image,
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
    Widget child = _builder(context);
    if (widget.heroTag != null) {
      child = Hero(
        tag: widget.heroTag!,
        child: child,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius ?? ((widget.size ?? 0) / 2)),
      child: child,
    );
  }
}

class Logo extends StatefulWidget {
  final String domain;
  final List<String> urls;
  final double size;

  const Logo({
    Key? key,
    required this.domain,
    required this.urls,
    required this.size,
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
        KeyManager.instance.setDomainLogo(widget.domain, url);
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
      return MultiImage(
        image: _fileInfo!.file.path,
        size: widget.size,
      );
    } else {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: _exhausted ? Icon(Icons.language, size: min(widget.size, widget.size)) : CircularProgressIndicator(),
        ),
      );
    }
  }
}

class KeybaseThumbnail extends StatefulWidget {
  final String? username;
  final double size;

  const KeybaseThumbnail({Key? key, required this.username, required this.size}) : super(key: key);

  @override
  State<KeybaseThumbnail> createState() => _KeybaseThumbnailState();
}

class _KeybaseThumbnailState extends State<KeybaseThumbnail> {
  static final Map<String, String?> _cache = {};
  String? _url;

  @override
  void initState() {
    super.initState();
    if (widget.username == null) {
      _url = "";
    } else {
      if (_cache.containsKey(widget.username!)) {
        setState(() {
          _url = _cache[widget.username];
        });
        return;
      }
      Utils.httpGet("https://keybase.io/_/api/1.0/user/pic_url.json?username=${widget.username}").then((value) {
        if (!mounted) return;
        setState(() {
          _url = jsonDecode(value)["pic_url"];
          _cache[widget.username!] = _url;
        });
      });
    }
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
      if (_url!.isEmpty) {
        return Image.asset("assets/images/unknown.png", width: widget.size, height: widget.size);
      }
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

