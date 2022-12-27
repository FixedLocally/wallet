
import 'package:flutter/material.dart';

import 'image.dart';

class DomainInfoWidget extends StatelessWidget {
  final String domain;
  final String title;
  final List<String> logoUrls;

  const DomainInfoWidget({
    Key? key,
    required this.domain,
    required this.logoUrls,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16.0),
          ),
          padding: EdgeInsets.all(16.0),
          child: Logo(
            domain: domain,
            urls: logoUrls,
            size: 64,
          ),
        ),
        SizedBox(height: 16),
        Text(
          title,
          style: theme.textTheme.headline6,
          textAlign: TextAlign.center,
        ),
        Text(domain, style: theme.textTheme.subtitle1,),
      ],
    );
  }
}
