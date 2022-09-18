import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jupiter_aggregator/jupiter_aggregator.dart';

import '../rpc/key_manager.dart';
import '../utils/utils.dart';

class WalletAppWidget extends StatefulWidget {
  final Widget child;

  const WalletAppWidget({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<WalletAppWidget> createState() => WalletAppWidgetState();
}

class WalletAppWidgetState extends State<WalletAppWidget> with WidgetsBindingObserver {
  // balances data
  final Map<String, Map<String, SplTokenAccountDataInfoWithUsd>> _balances = {};
  final Map<String, Completer> _balancesCompleters = {};
  final Map<String, Completer> _tokenInfoCompleters = {};
  final Map<String, Map<String, dynamic>> _tokenDetails = {};

  // swap data
  final JupiterAggregatorClient _jupClient = JupiterAggregatorClient();
  final Map<String, int> _jupTopTokens = {};
  JupiterIndexedRouteMap? _jupRouteMap;
  bool _jupRouteMapLoading = false;

  Timer? _balanceReloader;

  static WalletAppWidgetState of(BuildContext context) {
    final WalletAppWidgetState? result =
    context.findAncestorStateOfType<WalletAppWidgetState>();
    assert(result != null, 'No WalletAppWidgetState found in context');
    return result!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _balanceReloader = Timer(Duration(minutes: 1), () => _reloadActiveBalances(true));
  }

  Future<void> loadJupRouteIndex() async {
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

  void startLoadingBalances(String pubKey) {
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

  Future<List<JupiterRoute>> getQuotes({
    required String fromMint,
    required String toMint,
    required int amount,
  }) async {
    return _jupClient.getQuote(
      inputMint: fromMint,
      outputMint: toMint,
      amount: amount,
      // feeBps: 10,
    );
  }

  Future<JupiterSwapTransactions> getSwapTransactions({
    required String userPublicKey,
    required JupiterRoute route,
  }) async {
    return _jupClient.getSwapTransactions(
      userPublicKey: userPublicKey,
      route: route,
      // feeBps: 10,
    );
  }

  void _reloadActiveBalances([bool reschedule = false]) {
    if (KeyManager.instance.isReady) {
      startLoadingBalances(KeyManager.instance.pubKey);
    }
    if (reschedule) {
      _balanceReloader?.cancel();
      _balanceReloader = Timer(Duration(minutes: 1), () => _reloadActiveBalances(true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadActiveBalances(true);
    }
    if (state == AppLifecycleState.paused) {
      _balanceReloader?.cancel();
      _balanceReloader = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WalletAppInheritedWidget(
      jupRouteMapLoading: _jupRouteMapLoading,
      jupRouteMap: _jupRouteMap,
      jupTopTokens: _jupTopTokens,
      balances: _balances,
      balancesCompleters: _balancesCompleters,
      tokenInfoCompleters: _tokenInfoCompleters,
      tokenDetails: _tokenDetails,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }
}


class WalletAppInheritedWidget extends InheritedWidget {
  // balances data
  final Map<String, Map<String, SplTokenAccountDataInfoWithUsd>> balances;
  final Map<String, Completer> balancesCompleters;
  final Map<String, Completer> tokenInfoCompleters;
  final Map<String, Map<String, dynamic>> tokenDetails;

  // swap data
  final Map<String, int> jupTopTokens;
  final JupiterIndexedRouteMap? jupRouteMap;
  final bool jupRouteMapLoading;

  const WalletAppInheritedWidget({
    required this.balances,
    required this.balancesCompleters,
    required this.tokenInfoCompleters,
    required this.tokenDetails,
    required this.jupTopTokens,
    required this.jupRouteMap,
    required this.jupRouteMapLoading,
    required super.child,
    super.key,
  });

  static WalletAppInheritedWidget of(BuildContext context) {
    final WalletAppInheritedWidget? result =
        context.dependOnInheritedWidgetOfExactType<WalletAppInheritedWidget>();
    assert(result != null, 'No WalletAppInheritedWidget found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(WalletAppInheritedWidget oldWidget) {
    return balances != oldWidget.balances ||
        balancesCompleters != oldWidget.balancesCompleters ||
        tokenInfoCompleters != oldWidget.tokenInfoCompleters ||
        tokenDetails != oldWidget.tokenDetails ||
        jupTopTokens != oldWidget.jupTopTokens ||
        jupRouteMap != oldWidget.jupRouteMap ||
        jupRouteMapLoading != oldWidget.jupRouteMapLoading;
  }
}
