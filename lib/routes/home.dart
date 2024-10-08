import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:sprintf/sprintf.dart';
import 'package:url_launcher/url_launcher.dart';
import '../generated/l10n.dart';
import '../models/models.dart';
import '../rpc/constants.dart';
import '../rpc/errors/errors.dart';
import '../rpc/key_manager.dart';
import '../utils/extensions.dart';
import '../utils/sns.dart';
import '../utils/utils.dart';
import '../widgets/approve_tx.dart';
import '../widgets/bottom_sheet.dart';
import '../widgets/header.dart';
import '../widgets/image.dart';
import '../widgets/text_icon.dart';
import 'locked.dart';
import 'mixins/inherited.dart';
import 'settings.dart';
import 'tokens/tokens.dart';
import 'staking/validator_list.dart';
import 'tokens/yield.dart';
import 'webview.dart';

class HomeRoute extends StatefulWidget {
  const HomeRoute({Key? key}) : super(key: key);

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute> with UsesSharedData, WidgetsBindingObserver {
  int _page = 1;
  final GlobalKey<RefreshIndicatorState> _nftRefresherKey = GlobalKey();
  final GlobalKey<RefreshIndicatorState> _tokenRefresherKey = GlobalKey();

  late TextEditingController _fromAmtController;
  late TextEditingController _searchController;

  String? _from;
  String? _to;
  String _amt = "";
  String? _loadedAmt;
  int _chosenRoute = -1;
  bool _hasEnoughBalance = false;
  bool _locked = false;
  bool _enableWsol = false;
  bool _invertSwapPrice = false;

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
        _chosenRoute = -1;
        _amt = _fromAmtController.text;
      });
    });
    _from = Utils.prefs.getString(Constants.kKeySwapFrom) ?? nativeSol;
    _to = Utils.prefs.getString(Constants.kKeySwapTo) ?? usdcMint;
    _enableWsol = Utils.prefs.getBool(Constants.kKeyEnableWsol) ?? false;
    WidgetsBinding.instance.addObserver(this);
    if (Utils.prefs.getBool(Constants.kKeyRequireAuth) ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => const LockedRoute(),
            settings: const RouteSettings(name: "/lock"),
          ),
        ).then((value) => _locked = false);
        _locked = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // _reloadActiveBalances(true);
    }
    if (state == AppLifecycleState.paused) {
      if (Utils.prefs.getBool(Constants.kKeyRequireAuth) ?? false) {
        if (!_locked) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => const LockedRoute(),
              settings: const RouteSettings(name: "/lock"),
            ),
          ).then((value) => _locked = false);
          _locked = true;
        }
      }
    }
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
                PopupMenuItem(
                  value: 'resolve_sns',
                  child: Text(S.current.resolveSnsDomain),
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
                    Future<Signature> sigFuture = KeyManager.instance.sign(
                        message.codeUnits);
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
                                  "Base58: ${base58encode(
                                      snapshot.data!.bytes)}\n\n"
                                      "Hex: ${snapshot.data!.bytes.map((e) =>
                                      e.toRadixString(16).padLeft(2, '0'))
                                      .join()}",
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
                            child: Text(S.current.ok),
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
                  Clipboard.setData(
                      ClipboardData(text: KeyManager.instance.pubKey));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(S.current.addressCopied),
                    ),
                  );
                  break;
                case 'resolve_sns':
                  String? domain = await Utils.showInputDialog(
                    context: context,
                    prompt: S.current.resolveSnsDomain,
                    label: S.current.solDomain,
                  );
                  if (domain == null) break;
                  Future<DomainResolution> keyFuture = SnsResolver.resolve(domain);
                  showDialog(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: Text(S.current.resolveSnsDomain),
                        content: FutureBuilder<DomainResolution>(
                          future: keyFuture,
                          builder: (ctx, snapshot) {
                            if (snapshot.hasData) {
                              if (snapshot.data != null) {
                                return Text(
                                  sprintf(S.current.snsResolveResult, [snapshot.data!.domainKey.pubkey.toBase58(), snapshot.data!.owner?.toBase58()]),
                                );
                              } else {
                                return Text(S.current.failedToResolveDomain);
                              }
                            } else {
                              return Text(S.of(context).resolving);
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
                          // TextButton(
                          //   child: Text(S.current.copy),
                          //   onPressed: () {
                          //     Clipboard.setData(
                          //         ClipboardData(text: snapshot.data?.toBase58()));
                          //     Navigator.of(ctx).pop();
                          //   },
                          // ),
                        ],
                      );
                    },
                  );
              }
            },
          ),
        ],
        leading: Builder(builder: (ctx) {
          return IconButton(
            icon: TextIcon(text: KeyManager.instance.walletName),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          );
        }),
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
            icon: Icon(Icons.paid),
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

  Widget _createAppTile(BuildContext context, App app) {
    String? host = Uri.parse(app.url).host;
    String? logo = KeyManager.instance.getDomainLogo(host);
    Widget leading = Icon(Icons.language, size: 48,);
    if (logo != null) {
      // leading = Image.file(File(logo), width: 24, height: 24, errorBuilder: (_, __, ___) => Icon(Icons.language),);
      leading = MultiImage(image: logo, size: 48,);
    }
    return RawMaterialButton(
      child: Column(
        children: [
          leading,
          Text(app.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,),
        ],
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => DAppRoute(
            title: app.name,
            initialUrl: app.url,
          ),
          settings: const RouteSettings(name: "/browser"),
        )).then((value) {
          _tokenRefresherKey.currentState?.show();
          setState(() {});
        });
      },
      onLongPress: () {
        showModalBottomSheet<bool>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 16),
                Text(app.name),
                Text(app.url),
                ListTile(
                  title: Text(sprintf(S.current.removeThisDapp, [app.name])),
                  onTap: () async {
                    Future f = KeyManager.instance.removeDapp(app.id);
                    Navigator.pop(context); // the bottom sheet
                    await Utils.showLoadingDialog(
                      context: context,
                      future: f,
                      text: S.of(context).removingDapp,
                    );
                    setState(() {});
                  },
                ),
                ListTile(
                  title: Text(S.of(context).copyUrl),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: app.url));
                    Navigator.pop(context); // the bottom sheet
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(S.of(context).copyUrlSuccess),
                    ));
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _createWalletListTile(ManagedKey key) {
    bool selected = key.active && KeyManager.instance.mockPubKey == null;
    bool canRemove = KeyManager.instance.canRemoveHdWallet || key.keyType != "seed";
    return Slidable(
      endActionPane: canRemove ? ActionPane(
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
      ) : null,
      child: ListTile(
        leading: Stack(
          children: [
            TextIcon(text: key.name, radius: 16),
            if (selected)
              Positioned(
                right: 3,
                bottom: 3,
                child: CircleAvatar(
                  radius: 6,
                  backgroundColor: Colors.green,
                ),
              ),
          ],
        ),
        visualDensity: VisualDensity.compact,
        title: Text(key.name),
        style: ListTileStyle.drawer,
        subtitle: Text(key.pubKey, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () async {
          Navigator.pop(context);
          if (key.active) {
            return;
          }
          _tokenRefresherKey.currentState?.show();
          appWidget.startLoadingBalances(key.pubKey);
          await KeyManager.instance.setActiveKey(key);
          setState(() {});
        },
      ),
    );
  }

  Widget _dAppList() {
    return LayoutBuilder(
      builder: (ctx, _) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        children: [
          GridView.extent(
            maxCrossAxisExtent: 112,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ...KeyManager.instance.apps.map((dApp) {
                return _createAppTile(ctx, dApp);
              }),
            ],
          ),
        ],
      ),
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
                        settings: const RouteSettings(name: "/browser"),
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
        _tokenRefresherKey.currentState?.show();
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
                      fontWeight: FontWeight.w600,
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "${isPositive ? "+" : ""}${percent.toStringAsFixed(2)}%",
                        style: TextStyle(
                          fontSize: 20,
                          color: color,
                          fontWeight: FontWeight.w500,
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
                                settings: const RouteSettings(name: "/send_choose"),
                              ),
                            );
                          },
                          elevation: 2.0,
                          fillColor: themeData.colorScheme.primary,
                          padding: EdgeInsets.all(6.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99.0),
                            // side: BorderSide(
                            //   color: themeData.colorScheme.onSurface,
                            //   width: 2,
                            // ),
                          ),
                          child: Text(S.current.send,
                              style: TextStyle(fontSize: 17, color: themeData.colorScheme.onPrimary)),
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
                                settings: const RouteSettings(name: "/deposit"),
                              ),
                            );
                          },
                          elevation: 2.0,
                          fillColor: themeData.colorScheme.primary,
                          padding: EdgeInsets.all(6.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99.0),
                            // side: BorderSide(
                            //   color: themeData.colorScheme.onSurface,
                            //   width: 2,
                            // ),
                          ),
                          child: Text(S.current.receive,
                              style: TextStyle(fontSize: 17, color: themeData.colorScheme.onPrimary)),
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
    return Text("coming soon");
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
        NavigatorState nav = Navigator.of(context);
        if (sendOnly) {
          _pushSendToken(entry);
          return;
        }
        int option = await _showTokenMenu(entry);
        bool burn = false;
        switch (option) {
          case 0:
            // receive token
            nav.push(MaterialPageRoute(
              builder: (ctx) => const DepositTokenRoute(),
              settings: const RouteSettings(name: "/deposit"),
            ));
            break;
          case 1:
            // send token
            _pushSendToken(entry);
            break;
          case 2:
            // stake SOL
            nav.push(MaterialPageRoute(
              builder: (_) => ValidatorListRoute(),
              settings: const RouteSettings(name: "/validators"),
            ));
            break;
          case 3:
            // burn and close token acct
            burn = await Utils.showConfirmBottomSheet(
              context: context,
              title: sprintf(S.current.burnConfirm, [tokenDetails[entry.mint]?["symbol"] ?? entry.mint.shortened]),
              bodyBuilder: (_) => Text(S.current.burnConfirmContent),
            );
            break;
          case 4:
            // close token acct
            burn = await Utils.showConfirmBottomSheet(
              context: context,
              title: S.current.closeTokenAccount,
              bodyBuilder: (_) => Text(S.current.closeTokenAccountContent),
            );
            break;
          case 5:
            // load yield opportunities
            Utils.showLoadingDialog(
              context: context,
              future: Utils.getYieldOpportunities(entry.mint),
            ).then((List<YieldOpportunity> opportunities) {
              return showActionBottomSheet(
                context: context,
                title: S.current.yield,
                actions: [
                  ...opportunities.mapIndexed((i, e) => BottomSheetAction(
                    // title: "${e.name} (APY: ${e.apy}%)",
                    title: sprintf(S.current.yieldOpportunityTitle, [e.name, e.apy.toStringAsFixed(2)]),
                    value: i,
                  )),
                ],
              ).then((value) {
                if (value < 0) return;
                YieldOpportunity opportunity = opportunities[value];
                nav.push(
                  MaterialPageRoute(
                    builder: (_) => YieldDepositRoute(
                      opportunity: opportunity,
                      account: entry,
                      mint: entry.mint,
                      decimals: entry.tokenAmount.decimals,
                      symbol: tokenDetails[entry.mint]?["symbol"] ?? entry.mint.shortened,
                    ),
                    settings: const RouteSettings(name: "/deposit_yield"),
                  ),
                );
              });
            });
            break;
          case 6:
            // unwrap SOL
            burn = true;
            break;
        }
        if (burn) {
          List<Instruction> ixs = entry.burnAndCloseIxs();
          String msg = entry.burnAndCloseMessage();
          await Utils.showLoadingDialog(context: context, future: Utils.sendInstructions(ixs), text: msg);
          _tokenRefresherKey.currentState?.show();
          appWidget.startLoadingBalances(KeyManager.instance.pubKey);
        }
      },
      leading: leading,
      title: Text.rich(TextSpan(
        text: name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
        ),
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
          Text("\$ ${usd.toStringAsFixed(2)}", style: TextStyle(
            fontWeight: FontWeight.w500,
          )),
          if (usdChange > 0)
            Text("+\$ ${usdChange.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500,))
          else if (usdChange < 0)
            Text("-\$ ${(-usdChange).toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500,))
          else
            const Text("\$ -", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500,)),
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
        _tokenRefresherKey.currentState?.show();
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
          _tokenRefresherKey.currentState?.show();
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
                              settings: const RouteSettings(name: "/nft_details"),
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
                builder: (ctx) => WalletSettingsRoute(
                  onCreateWallet: () {
                    setState(() {
                      _page = 1;
                    });
                  }
                ),
                settings: const RouteSettings(name: "/settings/wallet"),
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
                settings: const RouteSettings(name: "/settings/security"),
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
            _tokenRefresherKey.currentState?.show();
            appWidget.startLoadingBalances(KeyManager.instance.pubKey);
            await Utils.showLoadingDialog(context: context, future: sharedData.balancesCompleters[KeyManager.instance.pubKey]!.future);
            List<SplTokenAccountDataInfoWithUsd> emptyAccounts = sharedData
                .balances[KeyManager.instance.pubKey]!.values
                .where((element) => element.tokenAmount.amount == "0" || (element.usd != null && element.usd! < 0.001))
                .toList();
            emptyAccounts.sort(Utils.compoundComparator([(a, b) => (a.tokenAmount.uiAmountString?.doubleParsed ?? 0.0).compareTo(b.tokenAmount.uiAmountString?.doubleParsed ?? 0.0), (a, b) => a.usd?.compareTo(b.usd ?? 0) ?? 0]));
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
            List<List<Instruction>> pendingIxs = [[]];
            int counter = 0;
            for (SplTokenAccountDataInfoWithUsd account in toClose) {
              if (counter >= 27) {
                pendingIxs.add([]);
                counter = 0;
              }
              List<Instruction> last = pendingIxs.last;
              if (account.tokenAmount.amount.doubleParsed > 0) {
                last.add(TokenInstruction.burnChecked(
                  amount: account.tokenAmount.amount.intParsed,
                  decimals: account.tokenAmount.decimals,
                  accountToBurnFrom: Ed25519HDPublicKey.fromBase58(account.account),
                  mint: Ed25519HDPublicKey.fromBase58(account.mint),
                  owner: Ed25519HDPublicKey.fromBase58(KeyManager.instance.pubKey),
                ));
                counter += 2;
              }
              last.add(
                TokenInstruction.closeAccount(
                  accountToClose: Ed25519HDPublicKey.fromBase58(account.account),
                  destination: Ed25519HDPublicKey.fromBase58(KeyManager.instance.pubKey),
                  owner: Ed25519HDPublicKey.fromBase58(KeyManager.instance.pubKey),
                ),
              );
              ++counter;
            }
            // each tx can only take 27 accounts
            for (int i = 0; i < pendingIxs.length; ++i) {
              await Utils.showLoadingDialog(context: context, future: Utils.sendInstructions(pendingIxs[i]));
            }
            _tokenRefresherKey.currentState?.show();
            appWidget.startLoadingBalances(KeyManager.instance.pubKey);
            scaffold.showSnackBar(SnackBar(content: Text(sprintf(S.current.tokenAccountsClosed, [toClose.length]))));
          },
        ),
        ListTile(
          title: Text("Debug"),
          onTap: () async {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => Scaffold(
                  appBar: AppBar(
                    title: Text("Debug"),
                  ),
                  body: Column(
                    children: [
                      ...List.generate(
                        9,
                        (index) => Text(
                          "ABC w${index + 1}00",
                          style: TextStyle(fontWeight: FontWeight.values[index]),
                        ),
                      ),
                    ],
                  ),
                ),
                settings: const RouteSettings(name: "/settings/debug"),
              ),
            ).then((value) {
              setState(() {});
            });
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

  Future<int> _showTokenMenu(SplTokenAccountDataInfoWithUsd balance) {
    String name = tokenDetails[balance.mint]?["name"] ?? balance.mint.shortened;
    return showActionBottomSheet(
      context: context,
      title: name,
      actions: [
        BottomSheetAction(
          leading: const Icon(Icons.call_received),
          title: S.current.receive,
          value: 0,
        ),
        BottomSheetAction(
          leading: const Icon(Icons.call_made),
          title: S.current.send,
          value: 1,
        ),
        if (balance.mint == nativeSol)
          BottomSheetAction(
            leading: const Icon(Icons.star),
            title: S.current.stake,
            value: 2,
          )
        else
          if (balance.tokenAmount.amount != "0")
            if (balance.mint == wrappedSolMint)
            BottomSheetAction(
              leading: const Icon(Icons.star),
              title: S.current.unwrapSol,
              value: 6,
            )
          else
              BottomSheetAction(
                leading: const Icon(Icons.close),
                title: S.current.burn,
                value: 3,
              )
          else
            BottomSheetAction(
              leading: const Icon(Icons.close),
              title: S.current.closeTokenAccount,
              value: 4,
            ),
        if (yieldableTokens.contains(balance.mint))
          BottomSheetAction(
            leading: const Icon(Icons.trending_up_rounded),
            title: S.current.yield,
            value: 5,
          )
      ],
    );
  }

  Future<void> _pushSendToken(SplTokenAccountDataInfoWithUsd balance) async {
    bool sent = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) =>
            SendTokenRoute(
              balance: balance,
              tokenDetails: tokenDetails[balance.mint] ?? {},
            ),
        settings: const RouteSettings(name: "/sendToken"),
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
      _chosenRoute = -1;
    });
    String fromMint = from;
    String toMint = to;
    fromMint = fromMint == nativeSol ? wrappedSolMint : fromMint;
    toMint = toMint == nativeSol ? wrappedSolMint : toMint;
    _loadedAmt = _fromAmtController.text;
    double amt = double.tryParse(_fromAmtController.text) ?? 0.0;
    int decimals = tokenDetails[from]!["decimals"]!;
    double amtIn = amt * pow(10, decimals);
    if (amtIn == 0) return;
    // print("loading routes from $amtIn $fromMint to $toMint");
    // print(StackTrace.current);
    setState(() {
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
    WidgetsBinding.instance.removeObserver(this);
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
              title: Text(info?["symbol"] ?? mint.shortened, style: TextStyle(fontWeight: FontWeight.w500),),
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
                subtitle: Text("${e.tokenAmount.uiAmountString ?? ""} ${sharedData.tokenDetails[e.mint]?["symbol"] ?? ""}"),
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
          onPressed: () async {
            List<SplTokenAccountDataInfoWithUsd> nonEmpty = _selected.where((element) => element.tokenAmount.amount != "0").toList();
            NavigatorState nav = Navigator.of(context);
            if (nonEmpty.isNotEmpty) {
              String msg = S.current.aboutToBurn;
              List<String> burnList = nonEmpty.map((e) => "${e.tokenAmount.uiAmountString} ${sharedData.tokenDetails[e.mint]?["symbol"] ?? e.mint.shortened}").toList();
              bool approved = await Utils.showConfirmBottomSheet(
                context: context,
                title: sprintf(S.current.burnConfirm, [sprintf(S.current.numTokens, [nonEmpty.length])]),
                bodyBuilder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg),
                    SizedBox(height: 8,),
                    ...burnList.map((e) => Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text("•"),
                        ),
                        Text(e),
                      ],
                    )),
                  ],
                ),
              );
              if (!approved) return;
            }
            nav.pop(_selected);
          },
          child: Text(S.of(context).cleanup),
        ),
      ],
    );
  }
}
