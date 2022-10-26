import 'package:flutter/material.dart';

import '../generated/l10n.dart';
import '../rpc/key_manager.dart';

class LockedRoute extends StatefulWidget {
  const LockedRoute({Key? key}) : super(key: key);

  @override
  State<LockedRoute> createState() => _LockedRouteState();
}

class _LockedRouteState extends State<LockedRoute> {
  @override
  void initState() {
    super.initState();
    KeyManager.instance.authenticateUser(context).then((value) {
      if (value) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              NavigatorState nav = Navigator.of(context);
              bool auth = await KeyManager.instance.authenticateUser(context);
              if (auth) {
                nav.pop();
              }
            },
            child: Text(S.current.unlockWallet),
          ),
        ),
      ),
      onWillPop: () async => false,
    );
  }
}
