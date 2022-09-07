import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:solana/base58.dart';

import '../generated/l10n.dart';
import '../rpc/key_manager.dart';
import '../utils/utils.dart';
import 'home.dart';

class ScaffoldRoute extends StatelessWidget {
  final String? title;
  final Widget? body;

  const ScaffoldRoute({
    super.key,
    this.title,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? ""),
      ),
      body: body,
    );
  }
}

class WalletSettingsRoute extends StatefulWidget {
  const WalletSettingsRoute({Key? key}) : super(key: key);

  @override
  State<WalletSettingsRoute> createState() => _WalletSettingsRouteState();
}

class _WalletSettingsRouteState extends State<WalletSettingsRoute> {
  @override
  Widget build(BuildContext context) {
    return ScaffoldRoute(
      title: S.current.walletSettings,
      body: Column(
        children: [
          ListTile(
            onTap: () async {
              String? name = await Utils.showInputDialog(
                context: context,
                prompt: S.current.newWalletName,
                initialValue: KeyManager.instance.walletName,
              );
              if (name != null) {
                await Utils.showLoadingDialog(
                  context: context,
                  future: KeyManager.instance.renameWallet(name),
                  text: S.current.renamingWallet,
                );
                setState(() {});
              }
            },
            title: Text(S.current.renameWallet),
          ),
          ListTile(
            onTap: () async {
              NavigatorState nav = Navigator.of(context);
              await Utils.showLoadingDialog(context: context, future: KeyManager.instance.createWallet(), text: S.current.creatingWallet);
              // ditch everything
              while (nav.canPop()) {
                nav.pop();
              }
              nav.push(MaterialPageRoute(builder: (_) => HomeRoute()));
            },
            title: Text(S.current.createWallet),
          ),
          ListTile(
            onTap: () async {
              NavigatorState nav = Navigator.of(context);
              String? key = await Utils.showInputDialog(
                context: context,
                prompt: S.current.enterNewKey,
              );
              if (key == null) {
                return;
              }
              List<int>? decodedKey;
              try {
                decodedKey = base58decode(key);
              } catch (_) {
                try {
                  decodedKey = (jsonDecode(key) as List).cast();
                } catch (_) {}
              }
              if (decodedKey == null || (decodedKey.length != 64 && decodedKey.length != 32)) {
                Utils.showInfoDialog(
                  context: context,
                  title: S.current.invalidKey,
                  content: S.current.invalidKeyContent,
                );
                return;
              }
              decodedKey = decodedKey.sublist(0, 32);
              await KeyManager.instance.importWallet(decodedKey);

              // ditch everything
              while (nav.canPop()) {
                nav.pop();
              }
              nav.push(MaterialPageRoute(builder: (_) => HomeRoute()));
            },
            title: Text(S.current.importWallet),
          ),
        ],
      ),
    );
  }
}

class SecuritySettingsRoute extends StatefulWidget {
  const SecuritySettingsRoute({Key? key}) : super(key: key);

  @override
  State<SecuritySettingsRoute> createState() => _SecuritySettingsRouteState();
}

class _SecuritySettingsRouteState extends State<SecuritySettingsRoute> {
  @override
  Widget build(BuildContext context) {
    return ScaffoldRoute(
      title: S.current.securitySettings,
      body: Column(
        children: [
          ListTile(
            onTap: () {
              KeyManager.instance.requestShowPrivateKey(context);
            },
            title: Text(S.current.exportPrivateKey),
          ),
          ListTile(
            onTap: () {
              KeyManager.instance.requestRemoveWallet(context, null);
            },
            title: Text(S.current.removeWallet),
          ),
          if (KeyManager.instance.isHdWallet)
            ...[
              ListTile(
                onTap: () {
                  KeyManager.instance.requestShowRecoveryPhrase(context);
                },
                title: Text(S.current.exportSecretRecoveryPhrase),
              ),
              ListTile(
                onTap: () {
                  // todo reset seed
                },
                title: Text(S.current.resetSecretRecoveryPhrase),
              ),
            ],
        ],
      ),
    );
  }
}
