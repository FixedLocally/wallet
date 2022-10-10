import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:jupiter_aggregator/jupiter_aggregator.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:sprintf/sprintf.dart';
import '../generated/l10n.dart';
import '../rpc/constants.dart';
import '../rpc/errors/errors.dart';
import '../rpc/key_manager.dart';
import '../utils/extensions.dart';
import '../utils/utils.dart';
import '../widgets/approve_tx.dart';
import '../widgets/header.dart';
import '../widgets/image.dart';
import 'mixins/inherited.dart';
import 'settings.dart';
import 'tokens/tokens.dart';
import 'staking/validator_list.dart';
import 'webview.dart';

class HomeRoute extends StatefulWidget {
  const HomeRoute({Key? key}) : super(key: key);

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute> with UsesSharedData {
  int _page = 1;
  final GlobalKey<RefreshIndicatorState> _nftRefresherKey = GlobalKey();
  final GlobalKey<RefreshIndicatorState> _tokenRefresherKey = GlobalKey();

  late TextEditingController _fromAmtController;
  late TextEditingController _searchController;

  String? _from;
  String? _to;
  String _amt = "";
  String? _loadedAmt;
  List<JupiterRoute>? _routes;
  int _chosenRoute = -1;
  bool _hasEnoughBalance = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _fromAmtController = TextEditingController();
    _fromAmtController.debounce(Duration(milliseconds: 400), (value) {
      _loadRoutes(_from, _to);
    });
    _fromAmtController.addListener(() {
      if (_amt == _fromAmtController.text) return;
      setState(() {
        _routes = null;
        _chosenRoute = -1;
        _amt = _fromAmtController.text;
      });
    });
    _from = Utils.prefs.getString(Constants.kKeySwapFrom) ?? nativeSol;
    _to = Utils.prefs.getString(Constants.kKeySwapTo) ?? usdcMint;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Center(child: _title()),
        titleSpacing: 0,
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
                PopupMenuItem(
                  value: 'copy',
                  child: Text(S.current.copyAddress),
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
                case 'copy':
                  Clipboard.setData(ClipboardData(text: KeyManager.instance.pubKey));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(S.current.addressCopied),
                    ),
                  );
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
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sync_alt),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.collections),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "",
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
    String? host = Uri.parse(url).host;
    String? logo = KeyManager.instance.getDomainLogo(host);
    Widget leading = Icon(Icons.language);
    if (logo != null) {
      // leading = Image.file(File(logo), width: 24, height: 24, errorBuilder: (_, __, ___) => Icon(Icons.language),);
      leading = MultiImage(image: logo, size: 24,);
    }
    return ListTile(
      leading: leading,
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
              await KeyManager.instance.requestRemoveWallet(context, key);
              setState(() {});
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
        _createWebsiteListTile("Orca", "https://www.orca.so"),
        _createWebsiteListTile("Marinade Governance", "https://tribeca.so/gov/mnde/nftgauges/validator"),
        _createWebsiteListTile("Magic Eden", "https://magiceden.io"),
        _createWebsiteListTile("Frakt", "https://frakt.xyz/lend"),
        _createWebsiteListTile("Nirvana", "https://app.nirvana.finance"),
      ],
    );
  }
  
  Widget _title() {
    switch (_page) {
      case 0:
        return Utils.wrapField(
          wrapColor: Theme.of(context).cardColor,
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: S.current.searchOrEnterWebAddress,
                    border: InputBorder.none,
                  ),
                  textInputAction: TextInputAction.go,
                  onSubmitted: (text) {
                    Uri? uri = Uri.tryParse(text);
                    if (uri == null || uri.host.isEmpty) {
                      uri = Uri.parse("https://$text");
                    }
                    if (!uri.host.contains(".")) {
                      uri = Uri.parse("https://www.google.com/search?q=$text");
                    }
                    if (text.isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => DAppRoute(
                          title: text,
                          initialUrl: uri.toString(),
                        ),
                      ));
                      _searchController.clear();
                    }
                  },
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              _searchController.text.isNotEmpty ? IconButton(
                visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              ) : Container(),
            ],
          ),
        );
      case 1:
        return GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: KeyManager.instance.pubKey));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(S.current.addressCopied),
              ),
            );
          },
          child: Text("${KeyManager.instance.walletName} (${KeyManager.instance.pubKey.shortened})"),
        );
      case 2:
        return Text(S.current.swap);
      case 3:
        return Text(S.current.collectibles);
      case 4:
        return Text(S.current.settings);
      default:
        return Text(S.current.home);
    }
  }

  Widget _balanceList(ThemeData themeData, {bool tokensOnly = false}) {
    String pubKey = KeyManager.instance.pubKey;
    if (balances[pubKey] == null) {
      if (balancesCompleters[pubKey] == null) {
        appWidget.startLoadingBalances(pubKey);
      }
      return const Center(child: CircularProgressIndicator());
    } else {
      Map<String, SplTokenAccountDataInfoWithUsd> myBalances = Map.of(balances[pubKey]!);
      myBalances.removeWhere((key, value) => tokenDetails[key]?["decimals"] == 0);
      Widget child = ListView.builder(
        itemCount: myBalances.length + (tokensOnly ? 0 : 1),
        itemBuilder: (ctx, index) {
          if (index == 0 && !tokensOnly) {
            double totalUsd = myBalances.values.fold(
              0.0,
              (sum, balance) => sum + max(0.0, balance.usd ?? -1),
            );
            double totalUsdChange = myBalances.values.fold(
              0.0,
              (sum, balance) => sum + (balance.usdChange ?? 0),
            );
            double percent = totalUsd > 0
                ? (totalUsdChange / (totalUsd - totalUsdChange) * 100)
                : 0;
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
                  SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: S.current.send,
                        child: RawMaterialButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: Text(S.current.send),
                                  ),
                                  body: _balanceList(themeData, tokensOnly: true),
                                ),
                              ),
                            );
                          },
                          elevation: 2.0,
                          padding: EdgeInsets.all(6.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99.0),
                            side: BorderSide(
                              color: themeData.colorScheme.onSurface,
                              width: 2,
                            ),
                          ),
                          child: Text(S.current.send,
                              style: TextStyle(fontSize: 17)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Tooltip(
                        message: S.current.receive,
                        child: RawMaterialButton(
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DepositTokenRoute(),
                                ));
                          },
                          elevation: 2.0,
                          padding: EdgeInsets.all(6.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99.0),
                            side: BorderSide(
                              color: themeData.colorScheme.onSurface,
                              width: 2,
                            ),
                          ),
                          child: Text(S.current.receive,
                              style: TextStyle(fontSize: 17)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
          return _balanceListTile(
              myBalances.values.elementAt(index - (tokensOnly ? 0 : 1)),
              themeData,
              sendOnly: tokensOnly);
        },
      );
      if (tokensOnly) {
        return child;
      } else {
        return RefreshIndicator(
          key: _tokenRefresherKey,
          onRefresh: () {
            appWidget.startLoadingBalances(pubKey);
            return balancesCompleters[pubKey]!.future;
          },
          child: child,
        );
      }
    }
  }

  Widget _swap(ThemeData themeData) {
    String pubKey = KeyManager.instance.pubKey;
    if (balances[pubKey] == null || jupRouteMap == null || jupRouteMapLoading) {
      if (balancesCompleters[pubKey] == null) {
        appWidget.startLoadingBalances(pubKey);
      }
      appWidget.loadJupRouteIndex();
      return const Center(child: CircularProgressIndicator());
    } else {
      Map<String, SplTokenAccountDataInfoWithUsd> myBalances = Map.of(balances[pubKey]!);
      myBalances.removeWhere((key, value) => tokenDetails[key]?["decimals"] == 0);
      myBalances.removeWhere((key, value) => tokenDetails[key] == null);
      List<String> mintKeys = jupRouteMap!.mintKeys;
      mintKeys.removeWhere((element) => tokenDetails[element] == null);
      mintKeys.sort(Utils.compoundComparator([
        (a, b) => (myBalances[b]?.usd ?? 0).compareTo(myBalances[a]?.usd ?? 0),
        (a, b) => (jupTopTokens[a] ?? 6969) - (jupTopTokens[b] ?? 6969),
      ]));
      Map<String, dynamic> fromTokenDetail = tokenDetails[_from] ?? {};
      Map<String, dynamic> toTokenDetail = tokenDetails[_to] ?? {};
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
        child: ListView(
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
                    wrapColor: themeData.colorScheme.background,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            _chooseSwapToken(mintKeys).then((mintKey) {
                              if (mintKey == null) return;
                              setState(() {
                                _from = mintKey;
                                _loadedAmt = null;
                                _loadRoutes(_from, _to);
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
            if (_from != null)
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("${myBalances[_from]?.tokenAmount.uiAmountString ?? "0"} ${tokenDetails[_from]?["symbol"] ?? _from!.shortened}"),
                    SizedBox(width: 8),
                    TextButton(
                      style: ButtonStyle(
                        visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                      ),
                      onPressed: () {
                        double amt = (myBalances[_from]?.tokenAmount.uiAmountString?.doubleParsed ?? 0) / 2;
                        _fromAmtController.text = amt.toFixedTrimmed(tokenDetails[_from]?["decimals"] ?? 9);
                      },
                      child: Text(
                        S.current.halfCap,
                        style: TextStyle(
                          fontSize: 12
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    TextButton(
                      style: ButtonStyle(
                        visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                      ),
                      onPressed: () {
                        double bal = myBalances[_from]?.tokenAmount.uiAmountString?.doubleParsed ?? 0;
                        if (_from == nativeSol) {
                          bal -= 0.01;
                          bal = bal.clamp(0, double.infinity);
                        }
                        // String balStr = bal.toStringAsFixed(tokenDetails[_from]?["decimals"] ?? 9);
                        // balStr = balStr.replaceAllMapped(RegExp(r"(\d+\.\d*[1-9])(0+)"), (match) => match.group(1)!);
                        _fromAmtController.text = bal.toFixedTrimmed(tokenDetails[_from]?["decimals"] ?? 9);
                      },
                      child: Text(
                        S.current.maxCap,
                        style: TextStyle(
                          fontSize: 12
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                  ],
                ),
              ),
            IconButton(
              onPressed: () {
                int decimals = tokenDetails[_to!]!["decimals"]!;
                setState(() {
                  String? from = _from;
                  _from = _to;
                  _to = from;
                  _loadedAmt = null;
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
                    wrapColor: themeData.colorScheme.background,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            _chooseSwapToken(mintKeys).then((mintKey) {
                              if (mintKey == null) return;
                              setState(() {
                                _to = mintKey;
                                _loadedAmt = null;
                                _loadRoutes(_from, _to);
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
                  child: Text("${myBalances[_to]?.tokenAmount.uiAmountString ?? "0"} ${tokenDetails[_to]?["symbol"] ?? _to!.shortened}"),
                ),
              ),
            if (_fromAmtController.text.isNotEmpty)
              if (_routes != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _loadedAmt = null;
                          _routes = null;
                          _loadRoutes(_from, _to);
                        });
                      },
                      icon: Icon(Icons.refresh),
                    ),
                  ],
                ),
                ..._routes!.asMap().map((i, route) {
                    String path = route.marketInfos.map((e) => e.label).join(" > ");
                    return MapEntry(
                      i,
                      ListTile(
                        title: Text(path),
                        subtitle: Text("${route.outAmount / pow(10, tokenDetails[_to!]!["decimals"])}"),
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
                            onPressed: _hasEnoughBalance ? () async {
                              FocusScope.of(context).unfocus();
                              ScaffoldMessengerState scaffold = ScaffoldMessenger.of(context);
                              JupiterSwapTransactions swapTxs =
                              await appWidget.getSwapTransactions(
                                  userPublicKey: KeyManager.instance.pubKey,
                                  route: _routes![_chosenRoute]);
                              List<Uint8List> txs = [swapTxs.setupTransaction, swapTxs.swapTransaction, swapTxs.cleanupTransaction]
                                  .whereNotNull.map(base64Decode).map((x) => x.sublist(65)).toList();
                              Future<List<TokenChanges>> simulation = Utils.simulateTxs(txs, KeyManager.instance.pubKey);
                              bool approved = await Utils.showConfirmBottomSheet(
                                context: context,
                                bodyBuilder: (context) {
                                  return ApproveTransactionWidget(simulation: simulation);
                                },
                              );
                              if (approved) {
                                Utils.prefs.setString(Constants.kKeySwapFrom, _from!);
                                Utils.prefs.setString(Constants.kKeySwapTo, _to!);
                                appWidget.startLoadingBalances(pubKey);
                                await Utils.showLoadingDialog(context: context, future: balancesCompleters[pubKey]!.future, text: S.current.sendingTx);
                                double fromBefore = double.parse(balances[pubKey]?[_from]?.tokenAmount.uiAmountString ?? "0");
                                double toBefore = double.parse(balances[pubKey]?[_to]?.tokenAmount.uiAmountString ?? "0");
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
                                // clear input
                                setState(() {
                                  _fromAmtController.text = "";
                                  _amt = "";
                                  _routes = null;
                                  _chosenRoute = -1;
                                });
                                // _loadRoutes(_from, _to);
                                appWidget.startLoadingBalances(KeyManager.instance.pubKey);
                                await balancesCompleters[pubKey]!.future;
                                double fromAfter = double.parse(balances[pubKey]![_from]!.tokenAmount.uiAmountString ?? "0");
                                double toAfter = double.parse(balances[pubKey]![_to]!.tokenAmount.uiAmountString ?? "0");
                                String fromDelta = (fromBefore - fromAfter).toFixedTrimmed(9);
                                String toDelta = (toAfter - toBefore).toFixedTrimmed(9);
                                // rip out the trailing zeros
                                // rip parse hack
                                // fromDelta = double.parse(fromDelta).toString();
                                // toDelta = double.parse(toDelta).toString();
                                // fromDelta = fromDelta.replaceAll(RegExp(r"0+$"), "");
                                // toDelta = toDelta.replaceAll(RegExp(r"0+$"), "");
                                scaffold.showSnackBar(SnackBar(content: Text(sprintf(S.current.swapSuccess, [fromDelta, tokenDetails[_from]?["symbol"] ?? _from!.shortened, toDelta, tokenDetails[_to]?["symbol"] ?? _to!.shortened]))));
                              } else {
                                _loadedAmt = null;
                                _loadRoutes(_from, _to);
                              }
                            } : null,
                            child: Text(
                              _hasEnoughBalance ? S.current.swap : S.current.insufficientBalance,
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

  Widget _balanceListTile(SplTokenAccountDataInfoWithUsd entry, ThemeData themeData, {bool sendOnly = false}) {
    String name = tokenDetails[entry.mint]?["name"] ?? "";
    String symbol = tokenDetails[entry.mint]?["symbol"] ?? "";
    name = name.isNotEmpty ? name : entry.mint.shortened;
    Widget? leading;
    if (tokenDetails[entry.mint] != null) {
      String? image = tokenDetails[entry.mint]?["image"];
      if (image != null) {
        leading = MultiImage(image: image, size: 48);
      } else {
        leading = Image.asset("assets/images/unknown.png", width: 48, height: 48,);
      }
    } else {
      leading = Image.asset("assets/images/unknown.png", width: 48, height: 48,);
    }
    String uiAmountString = entry.tokenAmount.uiAmountString ?? "0";
    // double amount = double.parse(uiAmountString);
    // double unitPrice = entry.value.usd ?? -1;
    double usd = entry.usd ?? -1;
    double usdChange = (entry.usdChange ?? 0);
    Widget listTile = ListTile(
      onTap: () async {
        if (sendOnly) {
          _pushSendToken(entry);
          return;
        }
        _showTokenMenu(entry);
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
          if ((entry.delegateAmount?.amount ?? "0") != "0")
            WidgetSpan(
              child: GestureDetector(
                onTap: () async {
                  String? revokeTx = await entry.showDelegationWarning(context, symbol);
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
      endActionPane: entry.tokenAmount.amount == "0" ? ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            backgroundColor: Colors.red,
            onPressed: (ctx) async {
              ScaffoldMessengerState scaffold = ScaffoldMessenger.of(context);
              bool confirm = await Utils.showConfirmBottomSheet(
                context: context,
                title: S.current.closeTokenAccount,
                bodyBuilder: (_) => Text(S.current.closeTokenAccountContent),
                confirmText: S.current.close,
              );
              if (!confirm) {
                return;
              }
              Instruction ix = TokenInstruction.closeAccount(
                accountToClose: Ed25519HDPublicKey(base58decode(entry.account)),
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
    if (balances[pubKey] == null) {
      if (balancesCompleters[pubKey] == null) {
        appWidget.startLoadingBalances(pubKey);
      }
      return const Center(child: CircularProgressIndicator());
    } else {
      if (tokenInfoCompleters[pubKey]?.isCompleted != true) {
        return const Center(child: CircularProgressIndicator());
      }
      Map<String, SplTokenAccountDataInfoWithUsd> myBalances = Map.of(balances[pubKey]!);
      myBalances.removeWhere((key, value) => tokenDetails[key]?["decimals"] != 0);
      return RefreshIndicator(
        key: _nftRefresherKey,
        onRefresh: () {
          appWidget.startLoadingBalances(pubKey);
          return balancesCompleters[pubKey]!.future;
        },
        child: myBalances.isNotEmpty
            ? GridView(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  childAspectRatio: 1,
                  mainAxisSpacing: 16,
                ),
                children: myBalances.entries.where((element) => element.value.tokenAmount.uiAmountString != "0").map((entry) {
                  String name =
                      tokenDetails[entry.key]?["name"] ?? S.current.loading;
                  final susVal = tokenDetails[entry.key]?["sus"] ?? false;
                  bool sus = susVal == true || susVal == 1;
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
                          image: tokenDetails[entry.value.mint]?["image"],
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
                      if (sus)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.red.withOpacity(0.6),
                            ),
                            child: Text(
                              "SUS",
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
                              builder: (ctx) => NftDetailsRoute(
                                balance: entry.value,
                                tokenDetails:
                                    tokenDetails[entry.value.mint] ?? {},
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
          title: Text(S.of(context).walletSettings),
          onTap: () async {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => WalletSettingsRoute(),
              ),
            ).then((value) {
              setState(() {});
            });
          },
        ),
        ListTile(
          title: Text(S.current.securitySettings),
          onTap: () async {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => SecuritySettingsRoute(),
              ),
            ).then((value) {
              setState(() {});
            });
          },
        ),
        ListTile(
          title: Text(S.current.cleanupTokenAccounts),
          onTap: () async {
            ScaffoldMessengerState scaffold = ScaffoldMessenger.of(context);
            appWidget.startLoadingBalances(KeyManager.instance.pubKey);
            await Utils.showLoadingDialog(context: context, future: sharedData.balancesCompleters[KeyManager.instance.pubKey]!.future);
            List<SplTokenAccountDataInfoWithUsd> emptyAccounts = sharedData.balances[KeyManager.instance.pubKey]!.values.where((element) => element.tokenAmount.amount == "0").toList();
            if (emptyAccounts.isEmpty) {
              scaffold.showSnackBar(SnackBar(content: Text(S.current.noEmptyTokenAccounts)));
              return;
            }
            Set<SplTokenAccountDataInfoWithUsd> toClose = await showDialog(
              context: context,
              builder: (_) => _CloseEmptyAccountsDialog(
                emptyAccounts: emptyAccounts,
              ),
            ) ?? {};
            if (toClose.isEmpty) {
              return;
            }
            // each tx can only take 27 accounts
            for (int i = 0; i < toClose.length; i += 27) {
              List<Instruction> ixs = [];
              toClose.skip(i).take(27).forEach((account) {
                ixs.add(
                  TokenInstruction.closeAccount(
                    accountToClose: Ed25519HDPublicKey(base58decode(account.account)),
                    destination: Ed25519HDPublicKey(base58decode(KeyManager.instance.pubKey)),
                    owner: Ed25519HDPublicKey(base58decode(KeyManager.instance.pubKey)),
                  ),
                );
              });
              await Utils.showLoadingDialog(context: context, future: Utils.sendInstructions(ixs));
            }
            appWidget.startLoadingBalances(KeyManager.instance.pubKey);
            scaffold.showSnackBar(SnackBar(content: Text(sprintf(S.current.tokenAccountsClosed, [toClose.length]))));
          },
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
                title: Text(S.current.receive),
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
                onTap: () => _pushSendToken(balance),
              ),
              if (balance.mint == nativeSol)
                ListTile(
                  leading: const Icon(Icons.star),
                  title: Text(S.current.stake),
                  onTap: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ValidatorListRoute()));
                  },
                )
              else
                if (balance.tokenAmount.amount != "0")
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: Text(S.current.burn),
                    onTap: () async {
                      Navigator.pop(context);
                      bool burn = await Utils.showConfirmBottomSheet(
                        context: context,
                        title: sprintf(S.current.burnConfirm, [tokenDetails[balance.mint]?["symbol"] ?? balance.mint.shortened]),
                        bodyBuilder: (_) => Text(S.current.burnConfirmContent),
                      );
                      if (!burn) return;
                      List<Instruction> ixs = balance.burnAndCloseIxs();
                      await Utils.showLoadingDialog(context: context, future: Utils.sendInstructions(ixs), text: S.current.burningTokens);
                      appWidget.startLoadingBalances(KeyManager.instance.pubKey);
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: Text(S.current.closeTokenAccount),
                    onTap: () async {
                      Navigator.pop(context);
                      bool burn = await Utils.showConfirmBottomSheet(
                        context: context,
                        title: S.current.closeTokenAccount,
                        bodyBuilder: (_) => Text(S.current.closeTokenAccountContent),
                      );
                      if (!burn) return;
                      List<Instruction> ixs = balance.burnAndCloseIxs();
                      await Utils.showLoadingDialog(context: context, future: Utils.sendInstructions(ixs), text: S.current.burningTokens);
                      appWidget.startLoadingBalances(KeyManager.instance.pubKey);
                    },
                  ),
              ListTile(
                leading: const Icon(Icons.trending_up_rounded),
                title: Text(S.current.yield),
                onTap: () async {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pushSendToken(SplTokenAccountDataInfoWithUsd balance) async {
    bool sent = await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (ctx) =>
            SendTokenRoute(
              balance: balance,
              tokenDetails: tokenDetails[balance.mint] ?? {},
            ),
      ),
    ) ?? false;
    if (sent) {
      if (_page == 2) _nftRefresherKey.currentState?.show();
      if (_page == 1) _tokenRefresherKey.currentState?.show();
    }
  }
  
  Future<void> _loadRoutes(String? from, String? to) async {
    if (from == null || to == null || _loadedAmt == _fromAmtController.text) {
      return;
    }
    setState(() {
      _routes = null;
      _chosenRoute = -1;
    });
    String fromMint = from;
    String toMint = to;
    fromMint = fromMint == nativeSol ? nativeSolMint : fromMint;
    toMint = toMint == nativeSol ? nativeSolMint : toMint;
    _loadedAmt = _fromAmtController.text;
    double amt = double.tryParse(_fromAmtController.text) ?? 0.0;
    int decimals = tokenDetails[from]!["decimals"]!;
    double amtIn = amt * pow(10, decimals);
    if (amtIn == 0) return;
    // print("loading routes from $amtIn $fromMint to $toMint");
    // print(StackTrace.current);
    List<JupiterRoute> routes = await appWidget.getQuotes(
      fromMint: fromMint,
      toMint: toMint,
      amount: amtIn.floor(),
      // feeBps: 10,
    );
    setState(() {
      _routes = routes;
      _chosenRoute = 0;
      _hasEnoughBalance = double.parse(balances[KeyManager.instance.pubKey]![_from]?.tokenAmount.uiAmountString ?? "0") >= (double.tryParse(_fromAmtController.text) ?? 0.0);
    });
  }

  Future<String?> _chooseSwapToken(List<String> mintKeys) async {
    String pubKey = KeyManager.instance.pubKey;

    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return _ChooseTokenDialog(
          balances: balances[pubKey] ?? {},
          jupTopTokens: jupTopTokens,
          mintKeys: [nativeSol, ...mintKeys],
          tokenDetails: tokenDetails,
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

class _ChooseTokenDialog extends StatefulWidget {
  final Map<String, int> jupTopTokens;
  final List<String> mintKeys;
  final Map<String, SplTokenAccountDataInfoWithUsd> balances;
  final Map<String, Map<String, dynamic>?> tokenDetails;

  const _ChooseTokenDialog({
    Key? key,
    required this.jupTopTokens,
    required this.mintKeys,
    required this.balances,
    required this.tokenDetails,
  }) : super(key: key);

  @override
  State<_ChooseTokenDialog> createState() => _ChooseTokenDialogState();
}

class _ChooseTokenDialogState extends State<_ChooseTokenDialog> {
  late List<String> _filteredMints;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    Map<String, SplTokenAccountDataInfoWithUsd> balances = widget.balances;
    _filteredMints = widget.mintKeys;
    _filteredMints.sort(Utils.compoundComparator([
          (a, b) => (balances[b]?.usd ?? 0).compareTo(balances[a]?.usd ?? 0),
          (a, b) => (balances[b]?.tokenAmount.uiAmountString?.doubleParsed ?? -9).compareTo(balances[a]?.tokenAmount.uiAmountString?.doubleParsed ?? -9),
          (a, b) => (widget.jupTopTokens[a] ?? 6969) - (widget.jupTopTokens[b] ?? 6969),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mq = MediaQuery.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(16.0, 20.0, 8.0, 0.0),
      contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
      title: Row(
        children: [
          Icon(
            Icons.search,
          ),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                isDense: true,
                // contentPadding: EdgeInsets.zero,
                hintText: S.current.searchTokensOrPasteAddress,
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {
                  _filteredMints = widget.mintKeys.where((element) => (widget.tokenDetails[element]?["symbol"]?.toLowerCase().contains(value.toLowerCase()) ?? false) || element == value).toList();
                });
              },
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity(horizontal: -4, vertical: -4),
            icon: Icon(Icons.clear),
            onPressed: () {
              if (_searchController.text.isEmpty) {
                Navigator.of(context).pop();
                return;
              }
              _searchController.clear();
              setState(() {
                _filteredMints = widget.mintKeys;
              });
            },
          ),
        ],
      ),
      content: SizedBox(
        height: mq.size.height - mq.padding.top - mq.padding.bottom - 200,
        width: 300,
        child: ListView.builder(
          itemBuilder: (ctx, i) {
            String mint = _filteredMints[i];
            Map<String, dynamic>? info = widget.tokenDetails[mint];
            return ListTile(
              visualDensity: VisualDensity(horizontal: -4),
              contentPadding: EdgeInsets.zero,
              leading: info?["image"] != null ? MultiImage(
                image: info?["image"],
                size: 32,
              ) : null,
              title: Text(info?["symbol"] ?? mint.shortened),
              subtitle: Text(info?["name"] ?? ""),
              trailing: widget.balances[mint] != null ? Text(widget.balances[mint]?.tokenAmount.uiAmountString ?? "0") : null,
              onTap: () {
                Navigator.pop(context, mint);
              },
            );
          },
          itemCount: _filteredMints.length,
          // shrinkWrap: true,
        ),
      ),
    );
  }
}

class _CloseEmptyAccountsDialog extends StatefulWidget {
  final List<SplTokenAccountDataInfoWithUsd> emptyAccounts;

  const _CloseEmptyAccountsDialog({
    Key? key,
    required this.emptyAccounts,
  }) : super(key: key);

  @override
  State<_CloseEmptyAccountsDialog> createState() => _CloseEmptyAccountsDialogState();
}

class _CloseEmptyAccountsDialogState extends State<_CloseEmptyAccountsDialog> with UsesSharedData {
  List<SplTokenAccountDataInfoWithUsd> get emptyAccounts => widget.emptyAccounts;
  final Set<SplTokenAccountDataInfoWithUsd> _selected = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.current.cleanupTokenAccounts),
      content: SizedBox(
        height: 400,
        width: 300,
        child: ListView(
          children: [
            ...emptyAccounts.map((e) {
              late Widget secondary;
              if (sharedData.tokenDetails[e.mint]?["image"] != null) {
                secondary = MultiImage(
                  image: sharedData.tokenDetails[e.mint]?["image"],
                  size: 40,
                );
              } else {
                secondary = Image.asset(
                  "assets/images/unknown.png",
                  width: 40,
                  height: 40,
                );
              }
              return CheckboxListTile(
                value: _selected.contains(e),
                secondary: secondary,
                onChanged: (b) {
                  if (b == true) {
                    setState(() {
                      _selected.add(e);
                    });
                  } else {
                    setState(() {
                      _selected.remove(e);
                    });
                  }
                },
                title: Text(sharedData.tokenDetails[e.mint]?["name"] ?? e.mint.shortened),
                subtitle: Text(sharedData.tokenDetails[e.mint]?["symbol"] ?? ""),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(S.current.cancel),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _selected.addAll(emptyAccounts);
            });
          },
          child: Text(S.current.selectAll),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, _selected);
          },
          child: Text(S.of(context).cleanup),
        ),
      ],
    );
  }
}

