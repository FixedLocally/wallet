import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/material.dart';

import '../generated/l10n.dart';
import 'seeds/generate_seed.dart';
import 'seeds/restore_seed.dart';

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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(S.current.setupWalletContent, style: Theme.of(context).textTheme.headline5,),
            const SizedBox(height: 20,),
            ElevatedButton(
              child: Text(S.current.importWallet),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RestoreSeedRoute()),
                );
              },
            ),
            ElevatedButton(
              child: Text(S.current.createWallet),
              onPressed: () async {
                String mnemonic = bip39.generateMnemonic();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GenerateSeedRoute(
                    mnemonic: mnemonic.split(" "),
                  )),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
