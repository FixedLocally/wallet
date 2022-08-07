import 'package:flutter/material.dart';
import 'package:solana/solana.dart';

import '../utils/utils.dart';

class ApproveTransactionWidget extends StatelessWidget {
  final Future<TokenChanges> simulation;

  const ApproveTransactionWidget({Key? key, required this.simulation}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TokenChanges>(
      future: simulation,
      builder: (ctx, snapshot) {
        double solOffset = (snapshot.data?.solOffset ?? 0) / lamportsPerSol;
        return Column(
          children: [
            const Text("Approve transaction?"),
            if (snapshot.hasData)
              ...[
                ...snapshot.data!.changes.map((key, value) {
                  String mint = snapshot.data!.updatedAccounts[key]!.mint;
                  String symbol = Utils.getToken(mint)?["symbol"] ?? mint;
                  return MapEntry(key, Text("$symbol: ${value > 0 ? "+" : ""}${value.toStringAsFixed(6)}"));
                }).values,
                Text("SOL: ${solOffset > 0 ? "+" : ""}${solOffset.toStringAsFixed(6)}"),
              ]
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
