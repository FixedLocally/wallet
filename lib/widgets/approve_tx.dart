import 'package:flutter/material.dart';

import '../generated/l10n.dart';
import '../utils/utils.dart';
import 'domain_info.dart';

class ApproveTransactionWidget extends StatelessWidget {
  final String? domain;
  final String? title;
  final List<String>? logoUrls;
  final Future<List<TokenChanges>> simulation;

  const ApproveTransactionWidget({
    Key? key,
    required this.simulation,
    this.domain,
    this.title,
    this.logoUrls,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TokenChanges>>(
      future: simulation,
      builder: (ctx, snapshot) {
        return Column(
          children: [
            SizedBox(height: 8),
            if (domain != null && title != null && logoUrls != null)
              DomainInfoWidget(
                domain: domain!,
                title: title!,
                logoUrls: logoUrls!,
              ),
            Text(S.current.approveTransactionTitle),
            if (snapshot.hasData)
              ...snapshot.data!.map((e) => e.widget())
            else if (snapshot.hasError)
              Text(S.current.transactionMayFailToConfirm)
            else
              Text(S.current.loading),
          ],
        );
      },
    );
  }
}
