import 'package:flutter/material.dart';

import '../rpc/key_manager.dart';
import '../utils/utils.dart';
import 'root.dart';
import 'setup.dart';

class EntryPointRoute extends StatefulWidget {
  const EntryPointRoute({Key? key}) : super(key: key);

  @override
  State<EntryPointRoute> createState() => _EntryPointRouteState();
}

class _EntryPointRouteState extends State<EntryPointRoute> {
  @override
  void initState() {
    super.initState();
    Utils.loadAssets().then((value) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (ctx) {
          if (KeyManager.instance.isEmpty) {
            return const SetupRoute();
          } else {
            return const WalletAppWidget();
          }
        },
      ));
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loading Wallet...'),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
