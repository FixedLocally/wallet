import 'package:flutter/material.dart';
import 'package:solana/solana.dart';

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
            const Text("Approve transaction?"),
            if (snapshot.hasData)
              if (snapshot.data!.first.error)
                Text("Transaction may fail to confirm ${snapshot.error}")
              else
                ...snapshot.data!.map((e) => e.widget())
            else if (snapshot.hasError)
              Text("Transaction may fail to confirm ${snapshot.error}")
            else
              const Text("Loading..."),
          ],
        );
      },
    );
  }
}
