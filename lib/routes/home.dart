import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:jupiter_aggregator/jupiter_aggregator.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:sprintf/sprintf.dart';
import '../generated/l10n.dart';
import '../rpc/errors/errors.dart';
import '../rpc/key_manager.dart';
import '../utils/extensions.dart';
import '../utils/utils.dart';
import '../widgets/approve_tx.dart';
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

  final JupiterAggregatorClient _jupClient = JupiterAggregatorClient();
  final Map<String, int> _jupTopTokens = {};
  JupiterIndexedRouteMap? _jupRouteMap;
  bool _jupRouteMapLoading = false;

  late TextEditingController _fromAmtController;

  String? _from;
  String? _to;
  String _amt = "";
  List<JupiterRoute>? _routes;
  int _chosenRoute = -1;

  @override
  void initState() {
    super.initState();
    _fromAmtController = TextEditingController();
    _fromAmtController.debounce(Duration(milliseconds: 400), (value) {
      _loadRoutes();
    });
    _fromAmtController.addListener(() {
      if (_amt == _fromAmtController.text) return;
      setState(() {
        _routes = null;
        _chosenRoute = -1;
        _amt = _fromAmtController.text;
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
      balances.removeWhere((key, value) => _tokenDetails[key]?["decimals"] == 0);
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
                (sum, balance) => sum + max(0.0, balance.usd ?? -1),
              );
              double totalUsdChange = balances.values.fold(
                0.0,
                (sum, balance) => sum + (balance.usdChange ?? 0),
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
    if (_balances[pubKey] == null || _jupRouteMap == null || _jupRouteMapLoading) {
      if (_balancesCompleters[pubKey] == null) {
        _startLoadingBalances(pubKey);
      }
      _loadJupRouteIndex();
      return const Center(child: CircularProgressIndicator());
    } else {
      Map<String, SplTokenAccountDataInfoWithUsd> balances = Map.of(_balances[pubKey]!);
      balances.removeWhere((key, value) => _tokenDetails[key]?["decimals"] == 0);
      balances.removeWhere((key, value) => _tokenDetails[key] == null);
      List<String> mintKeys = _jupRouteMap!.mintKeys;
      mintKeys.removeWhere((element) => _tokenDetails[element] == null);
      mintKeys.sort(Utils.compoundComparator([
        (a, b) => (balances[b]?.usd ?? 0).compareTo(balances[a]?.usd ?? 0),
        (a, b) => (_jupTopTokens[a] ?? 6969) - (_jupTopTokens[b] ?? 6969),
      ]));
      Map<String, dynamic> fromTokenDetail = _tokenDetails[_from] ?? {};
      Map<String, dynamic> toTokenDetail = _tokenDetails[_to] ?? {};
      return TextButtonTheme(
        data: TextButtonThemeData(
          style: TextButton.styleFrom(
            primary: themeData.colorScheme.onPrimary,
            backgroundColor: themeData.colorScheme.primary,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            textStyle: themeData.textTheme.button?.copyWith(
              color: themeData.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
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
                    padding: EdgeInsets.only(left: 8, right: 16),
                    themeData: themeData,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            _chooseSwapToken(mintKeys).then((mintKey) {
                              if (mintKey == null) return;
                              setState(() {
                                _from = mintKey;
                                _loadRoutes();
                              });
                            });
                          },
                          child: Row(
                            children: [
                              Container(
                                constraints: BoxConstraints(minWidth: 28),
                                child: Text(fromTokenDetail["symbol"] ?? _from?.shortened ?? ""),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 20,),
                            ],
                          ),
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
            // todo: handle native sol balances correctly
            if (_from != null)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: Text("${balances[_from]?.tokenAmount.uiAmountString ?? "0"} ${_tokenDetails[_from]?["symbol"] ?? _from!.shortened}"),
                ),
              ),
            IconButton(
              onPressed: () {
                int decimals = _tokenDetails[_to!]!["decimals"]!;
                setState(() {
                  String? from = _from;
                  _from = _to;
                  _to = from;
                  if (_routes != null && _routes!.isNotEmpty) {
                    _amt = (_routes!.first.outAmount / pow(10, decimals)).toString();
                    _fromAmtController.text = _amt;
                  }
                  _routes = null;
                });
              },
              icon: Icon(Icons.swap_vert),
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
                    padding: EdgeInsets.only(left: 8, right: 16),
                    themeData: themeData,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            _chooseSwapToken(mintKeys).then((mintKey) {
                              if (mintKey == null) return;
                              setState(() {
                                _to = mintKey;
                                _loadRoutes();
                              });
                            });
                          },
                          child: Row(
                            children: [
                              Container(
                                constraints: BoxConstraints(minWidth: 28),
                                child: Text(toTokenDetail["symbol"] ?? _to?.shortened ?? ""),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 20,),
                            ],
                          ),
                        ),
                        Spacer(),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 16),
              ],
            ),
            if (_to != null)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: Text("${balances[_to]?.tokenAmount.uiAmountString ?? "0"} ${_tokenDetails[_to]?["symbol"] ?? _to!.shortened}"),
                ),
              ),
            if (_fromAmtController.text.isNotEmpty)
              if (_routes != null)
                ...[
                  ..._routes!.asMap().map((i, route) {
                    String path = route.marketInfos.map((e) => e.label).join(" > ");
                    return MapEntry(
                      i,
                      ListTile(
                        title: Text(path),
                        subtitle: Text("${route.outAmount / pow(10, _tokenDetails[_to!]!["decimals"])}"),
                        trailing: i == _chosenRoute ? Icon(Icons.check) : null,
                        onTap: () async {
                          setState(() {
                            _chosenRoute = i;
                          });
                        },
                      ),
                    );
                  }).values,
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              FocusScope.of(context).unfocus();
                              ScaffoldMessengerState scaffold = ScaffoldMessenger.of(context);
                              JupiterSwapTransactions swapTxs =
                              await _jupClient.getSwapTransactions(
                                  userPublicKey: KeyManager.instance.pubKey,
                                  route: _routes![_chosenRoute]);
                              List<Uint8List> txs = [swapTxs.setupTransaction, swapTxs.swapTransaction, swapTxs.cleanupTransaction]
                                  .whereNotNull.map(base64Decode).map((x) => x.sublist(65)).toList();
                              Future<List<TokenChanges>> simulation = Utils.simulateTxs(txs, KeyManager.instance.pubKey);
                              bool approved = await Utils.showConfirmBottomSheet(
                                context: context,
                                builder: (context) {
                                  return ApproveTransactionWidget(simulation: simulation);
                                },
                              );
                              if (approved) {
                                // send tx one by one
                                for (Uint8List tx in txs) {
                                  Completer completer = Completer();
                                  Utils.showLoadingDialog(context: context, future: completer.future, text: S.current.sendingTx);
                                  bool error = false;
                                  try {
                                    final bh = await Utils.getBlockhash();
                                    SignedTx signedTx = await KeyManager.instance
                                        .signMessage(Message.decompile(
                                        CompiledMessage(ByteArray(tx))), bh.blockhash);
                                    String sig = await Utils.sendTransaction(signedTx);
                                    await Utils.confirmTransaction(sig);
                                  } catch (e) {
                                    error = true;
                                  }
                                  completer.complete();
                                  if (error) {
                                    scaffold.showSnackBar(SnackBar(content: Text(S.current.errorSendingTxs)));
                                  }
                                }
                                // reload routes after trying to swap
                                _loadRoutes();
                                _startLoadingBalances(KeyManager.instance.pubKey);
                              }
                            },
                            child: Text(
                              S.of(context).swap,
                              style: themeData.textTheme.button,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
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
      } else {
        leading = Image.asset("assets/images/unknown.png", width: 48, height: 48,);
      }
    } else {
      leading = Image.asset("assets/images/unknown.png", width: 48, height: 48,);
    }
    String uiAmountString = entry.value.tokenAmount.uiAmountString ?? "0";
    // double amount = double.parse(uiAmountString);
    // double unitPrice = entry.value.usd ?? -1;
    double usd = entry.value.usd ?? -1;
    double usdChange = (entry.value.usdChange ?? 0);
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
                confirmText: S.current.close,
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
      balances.removeWhere((key, value) => _tokenDetails[key]?["decimals"] != 0);
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
                )
              else
                if (balance.tokenAmount.amount != "0")
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: Text(S.of(context).burn),
                    onTap: () async {
                      Navigator.pop(context);
                      bool burn = await Utils.showConfirmDialog(
                        context: context,
                        title: sprintf(S.current.burnConfirm, [_tokenDetails[balance.mint]?["symbol"] ?? balance.mint.shortened]),
                        content: S.current.burnConfirmContent,
                      );
                      if (!burn) return;
                      List<Instruction> ixs = [];
                      ixs.add(TokenInstruction.burn(
                        amount: int.parse(balance.tokenAmount.amount),
                        accountToBurnFrom: Ed25519HDPublicKey(base58decode(balance.account)),
                        mint: Ed25519HDPublicKey(base58decode(balance.mint)),
                        owner: Ed25519HDPublicKey(base58decode(balance.owner)),
                      ));
                      ixs.add(TokenInstruction.closeAccount(
                        accountToClose: Ed25519HDPublicKey(base58decode(balance.account)),
                        destination: Ed25519HDPublicKey(base58decode(balance.owner)),
                        owner: Ed25519HDPublicKey(base58decode(balance.owner)),
                      ));
                      await Utils.showLoadingDialog(context: context, future: Utils.sendInstructions(ixs), text: S.current.burningTokens);
                      _startLoadingBalances(KeyManager.instance.pubKey);
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: Text(S.of(context).closeTokenAccount),
                    onTap: () async {
                      Navigator.pop(context);
                      bool burn = await Utils.showConfirmDialog(
                        context: context,
                        title: S.current.closeTokenAccount,
                        content: S.current.closeTokenAccountContent,
                      );
                      if (!burn) return;
                      List<Instruction> ixs = [];
                      ixs.add(TokenInstruction.burn(
                        amount: int.parse(balance.tokenAmount.amount),
                        accountToBurnFrom: Ed25519HDPublicKey(base58decode(balance.account)),
                        mint: Ed25519HDPublicKey(base58decode(balance.mint)),
                        owner: Ed25519HDPublicKey(base58decode(balance.owner)),
                      ));
                      ixs.add(TokenInstruction.closeAccount(
                        accountToClose: Ed25519HDPublicKey(base58decode(balance.account)),
                        destination: Ed25519HDPublicKey(base58decode(balance.owner)),
                        owner: Ed25519HDPublicKey(base58decode(balance.owner)),
                      ));
                      await Utils.showLoadingDialog(context: context, future: Utils.sendInstructions(ixs), text: S.current.burningTokens);
                      _startLoadingBalances(KeyManager.instance.pubKey);
                    },
                  )
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
      _chosenRoute = -1;
    });
    String fromMint = _from!;
    String toMint = _to!;
    fromMint = fromMint == nativeSol ? nativeSolMint : fromMint;
    toMint = toMint == nativeSol ? nativeSolMint : toMint;
    double amt = double.tryParse(_fromAmtController.text) ?? 0.0;
    int decimals = _tokenDetails[_from!]!["decimals"]!;
    double amtIn = amt * pow(10, decimals);
    if (amtIn == 0) return;
    // print("loading routes from $amtIn $fromMint to $toMint");
    // print(StackTrace.current);
    List<JupiterRoute> routes = await _jupClient.getQuote(
      inputMint: fromMint,
      outputMint: toMint,
      amount: amtIn.floor(),
      // feeBps: 10,
    );
    setState(() {
      _routes = routes;
      _chosenRoute = 0;
    });
  }

  Future<void> _loadJupRouteIndex() async {
    if (_jupRouteMap != null || _jupRouteMapLoading) return;
    _jupRouteMapLoading = true;
    JupiterIndexedRouteMap routeMap = await _jupClient.getIndexedRouteMap();
    _jupRouteMap = routeMap;
    print("got jup map");
    List<String> topTokens = await Utils.getTopTokens();
    topTokens.asMap().forEach((key, value) {
      _jupTopTokens[value] = key;
    });
    List<String> mints = routeMap.mintKeys.toList();
    mints.removeWhere((element) => _tokenDetails.keys.contains(element));
    print(mints);
    Utils.getTokens(mints).then((value) {
      print("got ${value.length} tokens");
      setState(() {
        value.forEach((mint, info) {
          if (info != null) _tokenDetails[mint] = info;
        });
        _jupRouteMapLoading = false;
      });
    });
  }

  Future<String?> _chooseSwapToken(List<String> mintKeys) async {
    MediaQueryData mq = MediaQuery.of(context);
    String pubKey = KeyManager.instance.pubKey;
    Map<String, SplTokenAccountDataInfoWithUsd> balances = _balances[pubKey]!;
    mintKeys = [...mintKeys, nativeSol];
    mintKeys.sort(Utils.compoundComparator([
          (a, b) => (balances[b]?.usd ?? 0).compareTo(balances[a]?.usd ?? 0),
          (a, b) => (balances[b]?.tokenAmount.uiAmountString?.doubleParsed ?? -9).compareTo(balances[a]?.tokenAmount.uiAmountString?.doubleParsed ?? -9),
          (a, b) => (_jupTopTokens[a] ?? 6969) - (_jupTopTokens[b] ?? 6969),
    ]));

    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(S.current.chooseToken),
          contentPadding: const EdgeInsets.fromLTRB(12.0, 20.0, 12.0, 0.0),
          content: SizedBox(
            height: mq.size.height - mq.padding.top - mq.padding.bottom - 200,
            width: 300,
            child: ListView.builder(
              itemBuilder: (ctx, i) {
                String mint = mintKeys[i];
                Map<String, dynamic>? info = _tokenDetails[mint];
                return ListTile(
                  visualDensity: VisualDensity(horizontal: -4),
                  contentPadding: EdgeInsets.zero,
                  leading: info?["image"] != null ? MultiImage(
                    image: info?["image"],
                    size: 32,
                  ) : null,
                  title: Text(info?["symbol"] ?? mint.shortened),
                  subtitle: Text(info?["name"] ?? ""),
                  trailing: _balances[pubKey]?[mint] != null ? Text(_balances[pubKey]?[mint]?.tokenAmount.uiAmountString ?? "0") : null,
                  onTap: () {
                    Navigator.pop(context, mint);
                  },
                );
              },
              itemCount: mintKeys.length,
              // shrinkWrap: true,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    _fromAmtController.dispose();
  }
}
