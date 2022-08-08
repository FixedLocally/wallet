import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import '../rpc/key_manager.dart';
import 'webview.dart';

class HomeRoute extends StatefulWidget {
  const HomeRoute({Key? key}) : super(key: key);

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            onPressed: () async {
              TextEditingController controller = TextEditingController();
              await showDialog<String>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Enter the message to sign:"),
                        TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Message to sign',
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          Future<Signature> sigFuture = KeyManager.instance.sign("solana".codeUnits);
                          Navigator.pop(ctx);
                          showDialog(
                            context: context,
                            builder: (ctx) {
                              return AlertDialog(
                                title: const Text('Signature'),
                                content: FutureBuilder<Signature>(
                                  future: sigFuture,
                                  builder: (ctx, snapshot) {
                                    if (snapshot.hasData) {
                                      return Text(
                                        "Base58: ${base58encode(snapshot.data!.bytes)}\n"
                                        "Hex: ${snapshot.data!.bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}",
                                      );
                                    } else {
                                      return const Text('Signing...');
                                    }
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text('OK'),
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: const Text("OK"),
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(CupertinoIcons.signature),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: Stack(
                children: [
                  const Positioned(
                    top: 0,
                    left: 0,
                    child: Text('Wallet'),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      onPressed: () async {
                        print("creating wallet");
                        await KeyManager.instance.createWallet();
                        setState(() {});
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
            ...KeyManager.instance.wallets.map(_createWalletListTile),
          ],
        ),
      ),
      body: Column(
        children: [
          _createWebsiteListTile("Raydium", "https://raydium.io/pools"),
          _createWebsiteListTile("Zeta Markets", "https://mainnet.zeta.markets/"),
          _createWebsiteListTile("Jupiter", "https://jup.ag/"),
          _createWebsiteListTile("Solend", "https://solend.fi/dashboard"),
          _createWebsiteListTile("Tulip", "https://tulip.garden/lend"),
        ],
      ),
    );
  }

  Widget _createWebsiteListTile(String title, String url) {
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(title),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => DAppRoute(
            title: title,
            initialUrl: url,
          ),
        ));
      },
    );
  }

  Widget _createWalletListTile(ManagedKey key) {
    return ListTile(
      leading: key.active ? const Icon(Icons.check) : const Icon(Icons.language),
      visualDensity: VisualDensity.compact,
      title: Text(key.name),
      style: ListTileStyle.drawer,
      subtitle: Text(key.pubKey, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () async {
        await KeyManager.instance.setActiveKey(key);
      },
    );
  }
}
