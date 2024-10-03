import 'dart:async';

import 'package:flutter/material.dart';

import '../../utils/utils.dart';
import '../root.dart';

mixin UsesSharedData<T extends StatefulWidget> on State<T> {
  late WalletAppInheritedWidget _sharedData;
  late WalletAppWidgetState _appWidget;
  WalletAppInheritedWidget get sharedData => _sharedData;
  WalletAppWidgetState get appWidget => _appWidget;

  // balances data
  Map<String, Map<String, SplTokenAccountDataInfoWithUsd>> get balances => sharedData.balances;
  Map<String, Completer> get balancesCompleters => sharedData.balancesCompleters;
  Map<String, Completer> get tokenInfoCompleters => sharedData.tokenInfoCompleters;
  Map<String, Map<String, dynamic>> get tokenDetails => sharedData.tokenDetails;

  // swap data
  Map<String, int> get jupTopTokens => sharedData.jupTopTokens;
  bool get jupRouteMapLoading => sharedData.jupRouteMapLoading;

  // yield data
  List<String> get yieldableTokens => sharedData.yieldableTokens;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sharedData = WalletAppInheritedWidget.of(context);
    _appWidget = WalletAppWidgetState.of(context);
  }
}