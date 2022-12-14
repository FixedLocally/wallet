import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';
import 'package:xml/xml.dart';

String fixSvg(String svgStr) {
  // we move all <def> section to the top of the svg
  XmlDocument doc = XmlDocument.parse(svgStr);
  XmlElement svg = doc.childElements.where((element) => element.name.local == "svg").first;
  List<XmlElement> defs = svg.childElements.where((element) => element.name.local == "defs").toList();
  List<XmlElement> others = svg.childElements.where((element) => element.name.local != "defs").toList();
  // todo style elements
  svg.children.clear();
  svg.children.addAll(defs);
  svg.children.addAll(others);
  return doc.toString();
}

class StringSvg extends StatelessWidget {
  final double? width;
  final double? height;
  final String svg;

  const StringSvg({
    Key? key,
    required this.svg,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: SvgPicture.string(svg),
    );
  }
}


class NetworkSvg extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final bool cleanSvg;

  const NetworkSvg({
    Key? key,
    required this.url,
    this.width,
    this.height,
    this.cleanSvg = false,
  }) : super(key: key);

  @override
  State<NetworkSvg> createState() => _NetworkSvgState();
}

class _NetworkSvgState extends State<NetworkSvg> {
  String? _svg;

  @override
  void initState() {
    super.initState();
    _loadSvg();
  }

  Future<String> _downloadSvg() async {
    late File file;
    if (widget.url.startsWith("file://")) {
      file = File(widget.url.substring(7));
    } else {
      file = await DefaultCacheManager().getSingleFile(widget.url);
    }
    return file.readAsString();
  }

  void _loadSvg() {
    _downloadSvg().then((String data) {
      if (widget.cleanSvg) {
        data = fixSvg(data);
      }
      setState(() {
        _svg = data;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_svg == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      return StringSvg(
        width: widget.width,
        height: widget.height,
        svg: _svg!,
      );
    }
  }
}
