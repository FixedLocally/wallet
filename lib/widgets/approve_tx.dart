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
              if (snapshot.data!.error)
                Text("Transaction may fail to confirm ${snapshot.error}")
              else
                ...[
                  ...snapshot.data!.changes.map((key, value) {
                    String mint = snapshot.data!.updatedAccounts[key]!.mint;
                    String shortMint = mint.length > 5 ? "${mint.substring(0, 5)}..." : mint;
                    String symbol = snapshot.data!.tokens[mint]?["symbol"] ?? shortMint;
                    if (value != 0) {
                      return MapEntry(key, Text("$symbol: ${value > 0 ? "+" : ""}${value.toStringAsFixed(6)}"));
                    } else {
                      return MapEntry(key, const SizedBox.shrink());
                    }
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
