import 'package:flutter/material.dart';

import '../../generated/l10n.dart';

class ImportAccountsRoute extends StatefulWidget {
  final String mnemonic;

  const ImportAccountsRoute({Key? key, required this.mnemonic}) : super(key: key);

  @override
  State<ImportAccountsRoute> createState() => _ImportAccountsRouteState();
}

class _ImportAccountsRouteState extends State<ImportAccountsRoute> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.importWallet),
      ),
    );
  }
}
