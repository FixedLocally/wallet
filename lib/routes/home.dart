import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:jupiter_aggregator/jupiter_aggregator.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import '../generated/l10n.dart';
import '../rpc/errors/errors.dart';
import '../rpc/key_manager.dart';
import '../utils/extensions.dart';
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
  final GlobalKey<RefreshIndicatorState> _nftRefresherKey = GlobalKey();
  final GlobalKey<RefreshIndicatorState> _tokenRefresherKey = GlobalKey();

  late TextEditingController _fromAmtController;

  JupiterAggregatorClient jupClient = JupiterAggregatorClient();
  SplTokenAccountDataInfoWithUsd? _from;
  SplTokenAccountDataInfoWithUsd? _to;
  List<JupiterRoute>? _routes;

  @override
  void initState() {
    super.initState();
    _fromAmtController = TextEditingController();
    _fromAmtController.debounce(Duration(milliseconds: 400), (value) {
      _loadRoutes();
    });
    _fromAmtController.addListener(() {
      setState(() {
        _routes = null;
      });
    });
  }

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
                  PopupMenuItem(
                    value: 'sign',
                    child: Text(S.current.signMessage),
                  ),
                if (KeyManager.instance.mockPubKey == null)
                  PopupMenuItem(
                    value: 'mock',
                    child: Text(S.current.mockWallet),
                  )
                else
                  PopupMenuItem(
                    value: 'unmock',
                    child: Text(S.current.exitMockWallet),
                  ),
              ];
            },
            onSelected: (s) async {
              switch (s) {
                case 'sign':
                  String? message = await Utils.showInputDialog(
                    context: context,
                    prompt: S.current.signMessagePrompt,
                    label: S.current.signMessageHint,
                  );
                  if (message != null) {
                    Future<Signature> sigFuture = KeyManager.instance.sign(message.codeUnits);
                    showDialog(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: Text(S.current.signature),
                          content: FutureBuilder<Signature>(
                            future: sigFuture,
                            builder: (ctx, snapshot) {
                              if (snapshot.hasData) {
                                return Text(
                                  "Base58: ${base58encode(snapshot.data!.bytes)}\n\n"
                                      "Hex: ${snapshot.data!.bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}",
                                );
                              } else {
                                return Text(S.current.signing);
                              }
                            },
                          ),
                          actions: [
                            TextButton(
                              child: Text(S.current.ok),
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
                        title: Text(S.current.mockWalletPrompt),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: S.current.mockWalletAddress,
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
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Text(S.current.wallet),
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
        type: BottomNavigationBarType.fixed,
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
            icon: Icon(Icons.sync_alt),
            label: 'Swap',
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
              _removeWallet(key);
            },
            icon: Icons.delete_forever,
            label: S.current.removeWallet,
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
        _createWebsiteListTile("Zeta Markets (Multi-Assets)", "https://mainnet.zeta.markets/referral"),
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
        key: _tokenRefresherKey,
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

  Widget _swap(ThemeData themeData) {
    String pubKey = KeyManager.instance.pubKey;
    if (_balances[pubKey] == null) {
      if (_balancesCompleters[pubKey] == null) {
        _startLoadingBalances(pubKey);
      }
      return const Center(child: CircularProgressIndicator());
    } else {
      Map<String, SplTokenAccountDataInfoWithUsd> balances = Map.of(_balances[pubKey]!);
      balances.removeWhere((key, value) => _tokenDetails[key]?["nft"] == 1);
      balances.removeWhere((key, value) => _tokenDetails[key] == null);
      return DropdownButtonHideUnderline(
        child: Column(
          children: [
            SizedBox(height: 8),
            // input
            Row(
              children: [
                SizedBox(width: 16),
                SizedBox(
                  width: 64,
                  child: Text(S.current.pay),
                ),
                Expanded(
                  child: Utils.wrapField(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    themeData: themeData,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButton(
                          // isExpanded: true,
                          value: _from,
                          items: balances.entries.map((entry) {
                            Map<String, dynamic> tokenDetail = _tokenDetails[entry.key] ?? {};
                            return DropdownMenuItem(
                              value: entry.value,
                              child: Text(tokenDetail["symbol"] ?? entry.key.shortened),
                            );
                          }).toList(),
                          onChanged: (SplTokenAccountDataInfoWithUsd? acct) {
                            setState(() {
                              _from = acct;
                              _loadRoutes();
                            });
                          },
                        ),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.only(left: 8),
                              hintText: "0.00",
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            controller: _fromAmtController,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 16),
              ],
            ),
            // output
            Row(
              children: [
                SizedBox(width: 16),
                SizedBox(
                  width: 64,
                  child: Text(S.current.receive),
                ),
                Expanded(
                  child: Utils.wrapField(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    themeData: themeData,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButton(
                          // isExpanded: true,
                          value: _to,
                          items: balances.entries.map((entry) {
                            Map<String, dynamic> tokenDetail = _tokenDetails[entry.key] ?? {};
                            return DropdownMenuItem(
                              value: entry.value,
                              child: Text(tokenDetail["symbol"] ?? entry.key.shortened),
                            );
                          }).toList(),
                          onChanged: (SplTokenAccountDataInfoWithUsd? acct) {
                            setState(() {
                              _to = acct;
                              _loadRoutes();
                            });
                          },
                        ),
                        Spacer(),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 16),
              ],
            ),
            if (_fromAmtController.text.isNotEmpty)
              if (_routes != null)
                ..._routes!.map((e) {
                  String path = e.marketInfos.map((e) => e.label).join(" > ");
                  return ListTile(
                    title: Text(path),
                    subtitle: Text("${e.outAmount / pow(10, _tokenDetails[_to!.mint]!["decimals"])}"),
                    onTap: () async {
                      JupiterSwapTransactions txs = await jupClient.getSwapTransactions(userPublicKey: KeyManager.instance.pubKey, route: e);
                      print(txs.setupTransaction);
                      print(txs.swapTransaction);
                      print(txs.cleanupTransaction);

                    },
                  );
                })
              else
                Center(
                  child: CircularProgressIndicator(),
                ),
          ],
        ),
      );
    }
  }

  Widget _balanceListTile(MapEntry<String, SplTokenAccountDataInfoWithUsd> entry, ThemeData themeData) {
    String name = _tokenDetails[entry.key]?["name"] ?? "";
    String symbol = _tokenDetails[entry.key]?["symbol"] ?? "";
    name = name.isNotEmpty ? name : entry.key.shortened;
    Widget? leading;
    if (_tokenDetails[entry.key] != null) {
      String? image = _tokenDetails[entry.key]?["image"];
      if (image != null) {
        leading = MultiImage(image: image, size: 48);
      }
    } else {
      leading = Image.asset("assets/images/unknown.png", width: 48, height: 48,);
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
                    _tokenRefresherKey.currentState?.show();
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
                title: S.current.closeTokenAccount,
                content: S.current.closeTokenAccountContent,
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
                scaffold.showSnackBar(SnackBar(content: Text(S.current.txConfirmed)));
                _tokenRefresherKey.currentState?.show();
              } on BaseError catch (e) {
                scaffold.showSnackBar(SnackBar(content: Text(e.message.toString())));
                return;
              }
            },
            icon: Icons.close,
            label: S.current.closeTokenAccount,
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
        key: _nftRefresherKey,
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
                      _tokenDetails[entry.key]?["name"] ?? S.current.loading;
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
                        _nftRefresherKey.currentState?.show();
                      }
                    },
                    child: child,
                  );
                }).toList(),
              )
            : Center(
                child: Text(S.current.noCollectibles),
              ),
      );
    }
  }

  Widget _settings() {
    return ListView(
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
            await Utils.showLoadingDialog(context: context, future: KeyManager.instance.createWallet(), text: "Creating wallet...");
            setState(() {});
          },
          title: Text(S.current.createWallet),
        ),
        ListTile(
          onTap: () async {
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
            setState(() {});
          },
          title: Text(S.current.importWallet),
        ),
        ListTile(
          onTap: () {
            KeyManager.instance.requestShowPrivateKey(context);
          },
          title: Text(S.current.exportPrivateKey),
        ),
        ListTile(
          onTap: () {
            _removeWallet(null);
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
    );
  }

  Widget _body(ThemeData themeData) {
    switch (_page) {
      case 0:
        return _dAppList();
      case 1:
        return _balanceList(themeData);
      case 2:
        return _swap(themeData);
      case 3:
        return _nftList(themeData);
      case 4:
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
                title: Text(S.current.deposit),
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
                    if (_page == 2) _nftRefresherKey.currentState?.show();
                    if (_page == 1) _tokenRefresherKey.currentState?.show();
                  }
                },
              ),
              if (balance.mint == nativeSol)
                ListTile(
                  leading: const Icon(Icons.star),
                  title: Text(S.current.stake),
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

  Future _removeWallet(ManagedKey? key) async {
    late String msg;
    if (KeyManager.instance.isHdWallet) {
      msg = S.current.removeHdWalletContent;
    } else {
      msg = S.current.removeKeyWalletContent;
    }
    bool confirm = await Utils.showConfirmDialog(
      context: context,
      title: S.current.removeWallet,
      content: msg,
      confirmText: S.current.delete,
    );
    if (!confirm) {
      return;
    }
    await KeyManager.instance.removeWallet(key);
    setState(() {});
  }

  Future<void> _loadRoutes() async {
    if (_from == null || _to == null) {
      return;
    }
    setState(() {
      _routes = null;
    });
    String fromMint = _from!.mint;
    String toMint = _to!.mint;
    fromMint = fromMint == nativeSol ? nativeSolMint : fromMint;
    toMint = toMint == nativeSol ? nativeSolMint : toMint;
    double amt = double.tryParse(_fromAmtController.text) ?? 0.0;
    int decimals = _tokenDetails[_from!.mint]!["decimals"]!;
    double amtIn = amt * pow(10, decimals);
    List<JupiterRoute> routes = await jupClient.getQuote(
      inputMint: fromMint,
      outputMint: toMint,
      amount: amtIn.floor(),
      feeBps: 10,
    );
    setState(() {
      _routes = routes;
    });
  }

  @override
  void dispose() {
    super.dispose();
    _fromAmtController.dispose();
  }
}
