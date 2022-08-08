import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/material.dart';

import '../rpc/key_manager.dart';
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
                      content: _GenerateSeedRoute(
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
                            List<int> seed = bip39.mnemonicToSeed(mnemonic);
                            await KeyManager.instance.insertSeed(seed);
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

class _GenerateSeedRoute extends StatefulWidget {
  final List<String> mnemonic;

  const _GenerateSeedRoute({Key? key, required this.mnemonic}) : super(key: key);

  @override
  State<_GenerateSeedRoute> createState() => _GenerateSeedRouteState();
}

class _GenerateSeedRouteState extends State<_GenerateSeedRoute> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Your secret recovery phrase is:'),
        ...List.generate(4, (index) => Row(
          children: [
            Expanded(child: Text("${index * 3 + 1}. ${widget.mnemonic[index * 3 + 0]}")),
            Expanded(child: Text("${index * 3 + 2}. ${widget.mnemonic[index * 3 + 1]}")),
            Expanded(child: Text("${index * 3 + 3}. ${widget.mnemonic[index * 3 + 2]}")),
          ],
        )),
        const Text('Your secret recovery phrase is the ONE and ONLY way to access your wallet. DO NOT share it with anyone.'),
      ],
    );
  }
}
