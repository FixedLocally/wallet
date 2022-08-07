import 'package:flutter/material.dart';

import '../utils/utils.dart';
import 'home.dart';

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
          return const HomeRoute();
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
