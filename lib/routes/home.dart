import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import '../rpc/errors/errors.dart';
import '../rpc/key_manager.dart';
import '../utils/utils.dart';
import '../widgets/header.dart';
import '../widgets/image.dart';
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
  final Map<String, Completer> _tokenInfoCompleters = {};
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
                  String? message = await Utils.showInputDialog(
                    context: context,
                    prompt: "Enter the message to sign:",
                    label: "Message to sign",
                  );
                  if (message != null) {
                    Future<Signature> sigFuture = KeyManager.instance.sign(message.codeUnits);
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
                  }
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
        // type: BottomNavigationBarType.fixed,
        selectedItemColor: themeData.colorScheme.secondary,
        unselectedItemColor: themeData.unselectedWidgetColor,
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
            icon: Icon(Icons.collections),
            label: 'Collectibles',
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
        _createWebsiteListTile("Orca", "https://orca.so"),
      ],
    );
  }

  Widget _balanceList(ThemeData themeData) {
    String pubKey = KeyManager.instance.pubKey;
    if (_balances[pubKey] == null) {
      if (_balancesCompleters[pubKey] == null) {
        _startLoadingBalances(pubKey);
      }
      return const Center(child: CircularProgressIndicator());
    } else {
      Map<String, SplTokenAccountDataInfoWithUsd> balances = Map.of(_balances[pubKey]!);
      balances.removeWhere((key, value) => _tokenDetails[key]?["nft"] == 1);
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
                          "${isPositive ? "+" : "-"}\$ ${totalUsdChange.abs().toStringAsFixed(2)}",
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
        leading = MultiImage(image: image, size: 48);
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
      leading: leading,
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
          if ((entry.value.delegateAmount?.amount ?? "0") != "0")
            WidgetSpan(
              child: GestureDetector(
                onTap: () async {
                  String? revokeTx = await entry.value.showDelegationWarning(context, symbol);
                  if (revokeTx != null) {
                    _startLoadingBalances(KeyManager.instance.pubKey);
                  }
                },
                child: const Icon(Icons.warning, color: Colors.red),
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
                Utils.showLoadingDialog(context: context, future: Utils.sendInstructions([ix]));
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

  Widget _nftList(ThemeData themeData) {
    String pubKey = KeyManager.instance.pubKey;
    if (_balances[pubKey] == null) {
      if (_balancesCompleters[pubKey] == null) {
        _startLoadingBalances(pubKey);
      }
      return const Center(child: CircularProgressIndicator());
    } else {
      if (_tokenInfoCompleters[pubKey]?.isCompleted != true) {
        return const Center(child: CircularProgressIndicator());
      }
      Map<String, SplTokenAccountDataInfoWithUsd> balances = Map.of(_balances[pubKey]!);
      balances.removeWhere((key, value) => _tokenDetails[key]?["nft"] != 1);
      return RefreshIndicator(
        onRefresh: () {
          _startLoadingBalances(pubKey);
          return _balancesCompleters[pubKey]!.future;
        },
        child: balances.isNotEmpty
            ? GridView(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  childAspectRatio: 1,
                  mainAxisSpacing: 16,
                ),
                children: balances.entries.map((entry) {
                  String name =
                      _tokenDetails[entry.key]?["name"] ?? "Loading...";
                  name = name.isNotEmpty
                      ? name
                      : "${entry.key.substring(0, 5)}...";
                  Widget child = Stack(
                    children: [
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 16,
                        child: MultiImage(
                          image: _tokenDetails[entry.value.mint]!["image"],
                          size: 160,
                          borderRadius: 24,
                        ),
                      ),
                      Positioned(
                        bottom: 24,
                        left: 24,
                        right: 24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color:
                                themeData.colorScheme.surface.withOpacity(0.6),
                          ),
                          child: Text(
                            name.split("").join("\u200b"),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  );
                  return GestureDetector(
                    onTap: () async {
                      bool sent = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => SendTokenRoute(
                                balance: entry.value,
                                tokenDetails:
                                    _tokenDetails[entry.value.mint] ?? {},
                                nft: true,
                              ),
                            ),
                          ) ??
                          false;
                      if (sent) {
                        _startLoadingBalances(KeyManager.instance.pubKey);
                      }
                    },
                    child: child,
                  );
                }).toList(),
              )
            : const Center(
                child: Text("No Collectibles"),
              ),
      );
    }
  }

  Widget _settings() {
    return ListView(
      children: [
        ListTile(
          onTap: () async {
            await Utils.showLoadingDialog(context: context, future: KeyManager.instance.createWallet(), text: "Creating wallet...");
            setState(() {});
          },
          title: const Text("Create Wallet"),
        ),
        ListTile(
          onTap: () async {
            String? key = await Utils.showInputDialog(
              context: context,
              prompt: "Enter new key",
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
                title: "Invalid key",
                content: "Key must be a base58 encoded string or a JSON array of bytes",
              );
              return;
            }
            decodedKey = decodedKey.sublist(0, 32);
            await KeyManager.instance.importWallet(decodedKey);
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
        return _nftList(themeData);
      case 3:
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
                onTap: () async {
                  bool sent = await Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => SendTokenRoute(
                        balance: balance,
                        tokenDetails: _tokenDetails[balance.mint] ?? {},
                      ),
                    ),
                  ) ?? false;
                  if (sent) {
                    _startLoadingBalances(KeyManager.instance.pubKey);
                  }
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
    Completer balCompleter = Completer();
    Completer metadataCompleter = Completer();
    _balancesCompleters[pubKey] = balCompleter;
    _tokenInfoCompleters[pubKey] = metadataCompleter;
    Utils.getBalances(pubKey).then((value) async {
      balCompleter.complete();
      setState(() {
        _balances[pubKey] = value.asMap().map((key, value) =>
            MapEntry(value.mint, value));
      });
      List<String> mints = value.map((e) => e.mint).toList();
      mints.removeWhere((element) => _tokenDetails.keys.contains(element));
      Map<String, Map<String, dynamic>?> tokenInfos = await Utils.getTokens(mints);
      metadataCompleter.complete();
      setState(() {
        tokenInfos.forEach((mint, info) {
          if (info != null) _tokenDetails[mint] = info;
        });
      });
    });
  }
}
