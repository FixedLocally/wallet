import 'package:flutter/material.dart';

import '../generated/l10n.dart';
import '../utils/utils.dart';

class ApproveTransactionWidget extends StatelessWidget {
  final Future<List<TokenChanges>> simulation;

  const ApproveTransactionWidget({Key? key, required this.simulation}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TokenChanges>>(
      future: simulation,
      builder: (ctx, snapshot) {
        return Column(
          children: [
            Text(S.current.approveTransactionTitle),
            if (snapshot.hasData)
              ...snapshot.data!.map((e) => e.widget())
            else if (snapshot.hasError)
              Text(S.of(context).transactionMayFailToConfirm)
            else
              Text(S.current.loading),
          ],
        );
      },
    );
  }
}
