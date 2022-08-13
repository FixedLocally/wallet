import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import '../rpc/errors/errors.dart';
import '../rpc/key_manager.dart';
import '../utils/utils.dart';
import '../widgets/header.dart';
import '../widgets/svg.dart';
import 'tokens/tokens.dart';
import 'webview.dart';

class HomeRoute extends StatefulWidget {
  const HomeRoute({Key? key}) : super(key: key);

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute> {
  int _page = 0;
  final Map<String, Map<String, SplTokenAccountDataInfoWithUsd>> _balances = {};
  final Map<String, Completer> _balancesCompleters = {};
  final Map<String, Map<String, dynamic>> _tokenDetails = {};

  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(KeyManager.instance.walletName),
            Text(
              KeyManager.instance.pubKey,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) {
              return [
                if (KeyManager.instance.mockPubKey == null)
                  const PopupMenuItem(
                    value: 'sign',
                    child: Text('Sign Message'),
                  ),
                const PopupMenuItem(
                  value: 'create',
                  child: Text('Create Wallet'),
                ),
                if (KeyManager.instance.mockPubKey == null)
                  const PopupMenuItem(
                    value: 'mock',
                    child: Text('Mock Wallet'),
                  )
                else
                  const PopupMenuItem(
                    value: 'unmock',
                    child: Text('Exit Mock Wallet'),
                  ),
              ];
            },
            onSelected: (s) async {
              switch (s) {
                case 'sign':
                  TextEditingController controller = TextEditingController();
                  await showDialog<String>(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text("Enter the message to sign:"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                                            "Base58: ${base58encode(snapshot.data!.bytes)}\n\n"
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
                  break;
                case 'create':
                  await Utils.showLoadingDialog(context, KeyManager.instance.createWallet());
                  setState(() {});
                  break;
                case 'mock':
                  TextEditingController controller = TextEditingController();
                  await showDialog<String>(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text("Enter wallet address to mock:"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                labelText: 'Mock wallet address',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              KeyManager.instance.mockPubKey = controller.text;
                              Navigator.pop(ctx);
                              setState(() {});
                            },
                            child: const Text("OK"),
                          ),
                        ],
                      );
                    },
                  );
                  break;
                case 'unmock':
                  KeyManager.instance.mockPubKey = null;
                  setState(() {});
                  break;
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              delegate: SliverHeaderDelegate(
                builder: (ctx) {
                  return DrawerHeader(
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                    ),
                    child: Stack(
                      children: const [
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Text('Wallet'),
                        ),
                      ],
                    ),
                  );
                }
              ),
              pinned: true,
            ),
            ...KeyManager.instance.wallets.map((wallet) {
              return SliverToBoxAdapter(
                child: _createWalletListTile(wallet),
              );
            }),
          ],
        ),
      ),
      body: _body(themeData),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _page,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          setState(() {
            _page = index;
          });
        },
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
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            backgroundColor: Colors.red,
            onPressed: (ctx) async {
              bool confirm = await Utils.showConfirmDialog(
                context: context,
                title: "Remove wallet",
                content: "This will remove the wallet from this list, but you will be able to recover it later with the seed phrase.",
                confirmText: "Delete",
              );
              if (!confirm) {
                return;
              }
              await KeyManager.instance.removeWallet(key);
              setState(() {});
            },
            icon: Icons.delete_forever,
            label: "Remove Wallet",
          ),
        ],
      ),
      child: ListTile(
        leading: key.active && KeyManager.instance.mockPubKey == null ? const Icon(Icons.check) : const Icon(Icons.language),
        visualDensity: VisualDensity.compact,
        title: Text(key.name),
        style: ListTileStyle.drawer,
        subtitle: Text(key.pubKey, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () async {
          Navigator.pop(context);
          await KeyManager.instance.setActiveKey(key);
          setState(() {});
        },
      ),
    );
  }

  Widget _dAppList() {
    return Column(
      children: [
        _createWebsiteListTile("Raydium", "https://raydium.io/pools"),
        _createWebsiteListTile("Zeta Markets", "https://mainnet.zeta.markets/"),
        _createWebsiteListTile("Jupiter", "https://jup.ag/"),
        _createWebsiteListTile("Solend", "https://solend.fi/dashboard"),
        _createWebsiteListTile("Tulip", "https://tulip.garden/lend"),
        _createWebsiteListTile("Mango Markets", "https://trade.mango.markets"),
      ],
    );
  }

  Widget _balanceList(ThemeData themeData) {
    String pubKey = KeyManager.instance.pubKey;
    if (_balances[pubKey] == null) {
      if (_balancesCompleters[pubKey] == null) {
        _startLoadingBalances(pubKey);
      }
      return const CircularProgressIndicator();
    } else {
      Map<String, SplTokenAccountDataInfoWithUsd> balances = _balances[pubKey]!;
      return RefreshIndicator(
        onRefresh: () {
          _startLoadingBalances(pubKey);
          return _balancesCompleters[pubKey]!.future;
        },
        child: ListView.builder(
          itemCount: balances.length + 1,
          itemBuilder: (ctx, index) {
            if (index == 0) {
              double totalUsd = balances.values.fold(
                0.0,
                (sum, balance) => sum + max(0.0, balance.usd),
              );
              double totalUsdChange = balances.values.fold(
                0.0,
                (sum, balance) => sum + balance.usdChange,
              );
              double percent = totalUsd > 0 ? (totalUsdChange / (totalUsd - totalUsdChange) * 100) : 0;
              bool isPositive = totalUsdChange >= 0;
              Color color = isPositive ? Colors.green : Colors.red;
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text(
                      "\$ ${totalUsd.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${isPositive ? "+" : ""}\$ ${totalUsdChange.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 20,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${isPositive ? "+" : ""}${percent.toStringAsFixed(2)}%",
                          style: TextStyle(
                            fontSize: 20,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }
            return _balanceListTile(balances.entries.elementAt(index - 1), themeData);
          },
        ),
      );
    }
  }

  Widget _balanceListTile(MapEntry<String, SplTokenAccountDataInfoWithUsd> entry, ThemeData themeData) {
    String name = _tokenDetails[entry.key]?["name"] ?? "";
    String symbol = _tokenDetails[entry.key]?["symbol"] ?? "";
    name = name.isNotEmpty ? name : "${entry.key.substring(0, 5)}...";
    Widget? leading;
    if (_tokenDetails[entry.key] != null) {
      String? image = _tokenDetails[entry.key]?["image"];
      if (image != null) {
        Uri? uri = Uri.tryParse(image);
        if (uri?.data?.mimeType.startsWith("image/svg") == true) {
          leading = StringSvg(
            svg: uri!.data!.contentAsString(),
            width: 48,
            height: 48,
          );
        } else if (image.endsWith(".svg")) {
          leading = NetworkSvg(
            url: image,
            width: 48,
            height: 48,
          );
        } else {
          leading = CachedNetworkImage(
            imageUrl: image,
            height: 48,
            width: 48,
          );
        }
      }
    }
    String uiAmountString = entry.value.tokenAmount.uiAmountString ?? "0";
    // double amount = double.parse(uiAmountString);
    // double unitPrice = entry.value.usd ?? -1;
    double usd = entry.value.usd;
    double usdChange = entry.value.usdChange;
    Widget listTile = ListTile(
      onTap: () {
        _showTokenMenu(entry.value);
      },
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: leading ?? const SizedBox(width: 48, height: 48),
      ),
      title: Text.rich(TextSpan(
        text: name,
        children: [
          if (symbol.isNotEmpty)
            TextSpan(
              text: " ($symbol)",
              style: TextStyle(
                color: themeData.colorScheme.onBackground.withOpacity(0.8),
              ),
            ),
        ],
      )),
      subtitle: Text(uiAmountString),
      trailing: usd >= 0 ? Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text("\$ ${usd.toStringAsFixed(2)}"),
          if (usdChange > 0)
            Text("+\$ ${usdChange.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green))
          else if (usdChange < 0)
            Text("-\$ ${(-usdChange).toStringAsFixed(2)}", style: const TextStyle(color: Colors.red))
          else
            const Text("\$ -"),
        ],
      ) : null,
    );
    return Slidable(
      endActionPane: entry.value.tokenAmount.amount == "0" ? ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            backgroundColor: Colors.red,
            onPressed: (ctx) async {
              ScaffoldMessengerState scaffold = ScaffoldMessenger.of(context);
              bool confirm = await Utils.showConfirmDialog(
                context: context,
                title: "Close token account",
                content: "Another contract interaction may recreate this account.",
                confirmText: "Close",
              );
              if (!confirm) {
                return;
              }
              Instruction ix = TokenInstruction.closeAccount(
                accountToClose: Ed25519HDPublicKey(base58decode(entry.value.account)),
                destination: Ed25519HDPublicKey(base58decode(KeyManager.instance.pubKey)),
                owner: Ed25519HDPublicKey(base58decode(KeyManager.instance.pubKey)),
              );
              try {
                await Utils.sendInstruction(ix);
                scaffold.showSnackBar(const SnackBar(content: Text("Transaction confirmed")));
                _startLoadingBalances(KeyManager.instance.pubKey);
              } on BaseError catch (e) {
                scaffold.showSnackBar(SnackBar(content: Text(e.message.toString())));
                return;
              }
            },
            icon: Icons.close,
            label: "Close account",
          ),
        ],
      ) : null,
      child: listTile,
    );
  }

  Widget _settings() {
    return ListView(
      children: [
        ListTile(
          onTap: () async {
            setState(() {});
          },
          title: const Text("Import Wallet"),
        ),
      ],
    );
  }

  Widget _body(ThemeData themeData) {
    switch (_page) {
      case 0:
        return _dAppList();
      case 1:
        return _balanceList(themeData);
      case 2:
        return _settings();
      default:
        return const Text("lol");
    }
  }

  Future _showTokenMenu(SplTokenAccountDataInfoWithUsd balance) {
    return showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.call_received),
                title: const Text("Deposit"),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => const DepositTokenRoute(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.call_made),
                title: const Text("Send"),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => const SendTokenRoute(),
                    ),
                  );
                },
              ),
              if (balance.mint == nativeSol)
                ListTile(
                  leading: const Icon(Icons.star),
                  title: const Text("Stake"),
                  onTap: () {
                    Navigator.pop(ctx, 2);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _startLoadingBalances(String pubKey) {
    Completer completer = Completer();
    _balancesCompleters[pubKey] = completer;
    Utils.getBalances(pubKey).then((value) async {
      completer.complete();
      setState(() {
        _balances[pubKey] = value.asMap().map((key, value) =>
            MapEntry(value.mint, value));
      });
      List<String> mints = value.map((e) => e.mint).toList();
      mints.removeWhere((element) => _tokenDetails.keys.contains(element));
      Map<String, Map<String, dynamic>?> tokenInfos = await Utils.getTokens(mints);
      setState(() {
        tokenInfos.forEach((mint, info) {
          if (info != null) _tokenDetails[mint] = info;
        });
      });
    });
  }
}
