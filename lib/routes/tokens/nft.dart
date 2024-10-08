import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:solana/encoder.dart';
import 'package:sprintf/sprintf.dart';

import '../../generated/l10n.dart';
import '../../utils/extensions.dart';
import '../../utils/utils.dart';
import '../../widgets/image.dart';
import '../image.dart';
import '../webview.dart';
import 'tokens.dart';

class NftDetailsRoute extends StatelessWidget {
  final Map<String, dynamic> tokenDetails;
  final SplTokenAccountDataInfoWithUsd balance;

  const NftDetailsRoute({
    Key? key,
    required this.tokenDetails,
    required this.balance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    MediaQueryData mq = MediaQuery.of(context);
    String? url = tokenDetails["ext_url"];
    Uri? uri = url != null ? Uri.tryParse(url) : null;
    // for some reason `... ?? "[]"` could be null
    List attributes = jsonDecode(tokenDetails["attributes"]) ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(tokenDetails["name"]),
        actions: [
          PopupMenuButton(
            itemBuilder: (_) {
              return [
                if (uri != null)
                  ...[
                    PopupMenuItem(
                      value: 0,
                      child: Text(S.current.visitExternalUrl),
                    ),
                  ],
                PopupMenuItem(
                  value: 1,
                  child: Text(S.current.viewOnSolscan),
                ),
                PopupMenuItem(
                  value: 2,
                  child: Text(S.current.burn),
                ),
              ];
            },
            onSelected: (int value) async {
              switch (value) {
                case 0:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DAppRoute(
                        title: "",
                        initialUrl: url!,
                      ),
                      settings: const RouteSettings(name: "/browser"),
                    ),
                  );
                  break;
                case 1:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DAppRoute(
                        title: "",
                        initialUrl: "https://solscan.io/token/${balance.mint}",
                      ),
                      settings: const RouteSettings(name: "/browser"),
                    ),
                  );
                  break;
                case 2:
                  NavigatorState nav = Navigator.of(context);
                  bool burn = await Utils.showConfirmBottomSheet(
                    context: context,
                    title: sprintf(S.current.burnConfirm, [tokenDetails[balance.mint]?["symbol"] ?? balance.mint.shortened]),
                    bodyBuilder: (_) => Text(S.current.burnConfirmContent),
                  );
                  if (!burn) return;
                  List<Instruction> ixs = balance.burnAndCloseIxs();
                  await Utils.showLoadingDialog(context: context, future: Utils.sendInstructions(ixs), text: S.current.burningTokens);
                  nav.pop(true);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ImageRoute(heroTag: "image", image: tokenDetails["image"])));
            },
            child: Center(
              child: MultiImage(
                heroTag: "image",
                image: tokenDetails["image"],
                size: mq.size.width - 32,
                borderRadius: 16,
              ),
            ),
          ),
          if (tokenDetails["description"] != null)
          ...[
            const SizedBox(height: 16),
            Text(tokenDetails["description"]),
          ],
          const SizedBox(height: 16),
          ...attributes.map((attr) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${attr["trait_type"]}: "),
              Text("${attr["value"]}"),
            ],
          )),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    NavigatorState nav = Navigator.of(context);
                    bool sent = await nav.push(MaterialPageRoute(
                      builder: (ctx) => SendTokenRoute(
                        balance: balance,
                        tokenDetails: tokenDetails,
                        nft: true,
                      ),
                      )) ?? false;
                    if (sent) {
                      nav.pop(true);
                    }
                  },
                  child: Text(
                    S.current.send,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
