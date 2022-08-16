import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/material.dart';

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
        title: const Text('Setup Wallet'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text('Setup Wallet'),
            TextButton(
              child: const Text('Import Wallet'),
              onPressed: () {
                // Navigator.pushReplacement(context, MaterialPageRoute(
                //   builder: (ctx) {
                //     return const HomeRoute();
                //   },
                // ));
              },
            ),
            TextButton(
              child: const Text('Create Wallet'),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) {
                    String mnemonic = bip39.generateMnemonic();
                    return AlertDialog(
                      title: const Text('Create Wallet'),
                      content: GenerateSeedRoute(
                        mnemonic: mnemonic.split(" "),
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                          },
                        ),
                        TextButton(
                          child: const Text('Continue'),
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
