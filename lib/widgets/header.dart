import 'package:flutter/material.dart';

class SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final WidgetBuilder builder;

  double padding = 0;

  SliverHeaderDelegate({required this.builder});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    padding = MediaQuery.of(context).padding.top;
    return builder(context);
  }

  @override
  double get maxExtent => 128 + padding;

  @override
  double get minExtent => 128;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }

}