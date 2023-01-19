import 'dart:async';

import 'package:bip39/bip39.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:solana/solana.dart';

import '../../generated/l10n.dart';
import '../../rpc/key_manager.dart';
import '../../utils/extensions.dart';
import '../../utils/utils.dart';
import '../entry_point.dart';

class ImportAccountsRoute extends StatefulWidget {
  final String mnemonic;

  const ImportAccountsRoute({Key? key, required this.mnemonic}) : super(key: key);

  @override
  State<ImportAccountsRoute> createState() => _ImportAccountsRouteState();
}

class _ImportAccountsRouteState extends State<ImportAccountsRoute> {
  final List<Wallet> _wallets = [];
  final List<int> _balances = [];
  final Set<int> _chosenWallets = {};

  bool _loading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 10) {
        _load();
      }
    });
  }

  void _load() {
    if (_loading) return;
    _loading = true;
    compute(importAccounts, [widget.mnemonic, _wallets.length]).then((value) {
      setState(() {
        _wallets.addAll(value);
        _loading = false;
      });
      int len = _balances.length;
      _balances.addAll(value.map((e) => -1));
      Utils.getSolBalances(value.map((e) => e.address).toList()).then((value) {
        value.asMap().map((key, value) {
          setState(() {
            _balances[len + key] = value;
          });
          return MapEntry(key, value);
        });
      });
    });
  }

  Widget _body() {
    if (_wallets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(S.current.importWalletListHint),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _wallets.length + 1,
            itemBuilder: (context, index) {
              if (index == _wallets.length) {
                return const Center(child: CircularProgressIndicator());
              }
              return CheckboxListTile(
                value: _chosenWallets.contains(index),
                onChanged: (value) {
                  setState(() {
                    if (value!) {
                      _chosenWallets.add(index);
                    } else {
                      _chosenWallets.remove(index);
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(_wallets[index].address.shortened),
                // subtitle: Text(_wallets[index].),
                secondary: _balances[index] == -1
                    ? const CircularProgressIndicator()
                    : Text("${(_balances[index] / 1e9).toStringAsFixed(3)} SOL"),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.importWallet),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _chosenWallets.isEmpty
                ? null
                : () async {
                    Completer<void> completer = Completer();
                    NavigatorState nav = Navigator.of(context);
                    Utils.showLoadingDialog(context: context, future: completer.future);
                    List<int> indices = _chosenWallets.toList();
                    indices.sort();
                    await KeyManager.instance.insertSeed(widget.mnemonic, indices.first);
                    for (int index in indices.sublist(1)) {
                      await KeyManager.instance.createWallet(index);
                    }
                    completer.complete();
                    // until the loading dialog is popped
                    await WidgetsBinding.instance.endOfFrame;
                    KeyManager.instance.setActiveKey(KeyManager.instance.wallets.first);
                    nav.pop(); // to seed entry
                    nav.pop(); // to setup
                    nav.pushReplacement(MaterialPageRoute(
                      builder: (_) => EntryPointRoute(),
                      settings: const RouteSettings(name: "/"),
                    ));
                    print(KeyManager.instance.isEmpty);
                  },
          ),
        ],
      ),
      body: _body(),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }
}

Future<List<Wallet>> importAccounts(List args) async {
  String mnemonic = args[0];
  int offset = args[1];
  List<Wallet?> wallets = List.generate(20, (index) => null);
  List<Future> futures = [];
  List<int> seed = mnemonicToSeed(mnemonic);
  for (int i = 0; i < 20; i++) {
    futures.add(Wallet.fromSeedWithHdPath(seed: seed, hdPath: "m/44'/501'/${i + offset}'/0'").then((value) {
      wallets[i] = value;
    }));
  }
  await Future.wait(futures);
  return wallets.map((e) => e!).toList();
}