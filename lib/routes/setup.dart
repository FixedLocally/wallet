import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/material.dart';

import '../generated/l10n.dart';
import '../rpc/key_manager.dart';
import '../widgets/show_seed.dart';
import 'home.dart';

// m/44'/501'/0'/0'
class SetupRoute extends StatefulWidget {
  const SetupRoute({Key? key}) : super(key: key);

  @override
  State<SetupRoute> createState() => _SetupRouteState();
}

class _SetupRouteState extends State<SetupRoute> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.setupWallet),
      ),
      body: Center(
        child: Column(
          children: [
            Text(S.current.setupWallet),
            TextButton(
              child: Text(S.current.importWallet),
              onPressed: () {
                // Navigator.pushReplacement(context, MaterialPageRoute(
                //   builder: (ctx) {
                //     return const HomeRoute();
                //   },
                // ));
              },
            ),
            TextButton(
              child: Text(S.current.createWallet),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) {
                    String mnemonic = bip39.generateMnemonic();
                    return AlertDialog(
                      title: Text(S.current.createWallet),
                      content: GenerateSeedRoute(
                        mnemonic: mnemonic.split(" "),
                      ),
                      actions: [
                        TextButton(
                          child: Text(S.current.cancel),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                          },
                        ),
                        TextButton(
                          child: Text(S.current.continuE),
                          onPressed: () async {
                            await KeyManager.instance.insertSeed(mnemonic);
                            if (mounted) {
                              Navigator.of(ctx).pop(); // the dialog
                              // replace setup route
                              Navigator.pushReplacement(context, MaterialPageRoute(
                                builder: (ctx) {
                                  return const HomeRoute();
                                },
                              ));
                            }
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
