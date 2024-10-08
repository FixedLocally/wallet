import 'dart:async';

import 'package:flutter/material.dart';

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
  final Map<String, int> _jupTopTokens = {};
  bool _jupRouteMapLoading = false;

  // yield data
  final List<String> _yieldableTokens = [];

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
    // noop
  }

  void startLoadingBalances(String pubKey) {
    Completer balCompleter = Completer();
    Completer metadataCompleter = Completer();
    if (_yieldableTokens.isEmpty) {
      loadYieldableTokens();
    }
    _balancesCompleters[pubKey] = balCompleter;
    _tokenInfoCompleters[pubKey] = metadataCompleter;

    // no need to load balance more than once per minute
    _balanceReloader?.cancel();
    _balanceReloader = Timer(Duration(minutes: 1), () => _reloadActiveBalances(true));

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

  void _reloadActiveBalances([bool reschedule = false]) {
    if (KeyManager.instance.isReady) {
      startLoadingBalances(KeyManager.instance.pubKey);
    }
    if (reschedule) {
      _balanceReloader?.cancel();
      _balanceReloader = Timer(Duration(minutes: 1), () => _reloadActiveBalances(true));
    }
  }

  Future<void> loadYieldableTokens() async {
    Utils.getYieldableTokens().then((value) {
      setState(() {
        _yieldableTokens.clear();
        _yieldableTokens.addAll(value);
      });
    });
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
      jupTopTokens: _jupTopTokens,
      balances: _balances,
      balancesCompleters: _balancesCompleters,
      tokenInfoCompleters: _tokenInfoCompleters,
      tokenDetails: _tokenDetails,
      yieldableTokens: _yieldableTokens,
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
  final bool jupRouteMapLoading;

  // yield data
  final List<String> yieldableTokens;

  const WalletAppInheritedWidget({
    required this.balances,
    required this.balancesCompleters,
    required this.tokenInfoCompleters,
    required this.tokenDetails,
    required this.jupTopTokens,
    required this.jupRouteMapLoading,
    required this.yieldableTokens,
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
    // return balances != oldWidget.balances ||
    //     balancesCompleters != oldWidget.balancesCompleters ||
    //     tokenInfoCompleters != oldWidget.tokenInfoCompleters ||
    //     tokenDetails != oldWidget.tokenDetails ||
    //     jupTopTokens != oldWidget.jupTopTokens ||
    //     jupRouteMap != oldWidget.jupRouteMap ||
    //     jupRouteMapLoading != oldWidget.jupRouteMapLoading;
    return true; // oops excessive reusing of array/maps
  }
}
