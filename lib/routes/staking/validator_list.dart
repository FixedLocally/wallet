import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:solana/dto.dart' hide Instruction;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:sprintf/sprintf.dart';

import '../../generated/l10n.dart';
import '../../rpc/key_manager.dart';
import '../../utils/extensions.dart';
import '../../utils/utils.dart';
import '../../widgets/custom_expansion_tile.dart';
import '../../widgets/image.dart';
import '../mixins/inherited.dart';
import '../webview.dart';
import 'stake_accounts.dart';

double _stakeFee = 0.000010000; // 10k lamports

Future<List<VoteAccount>> _processVoteAccounts(List list) async {
  List<VoteAccount> voteAccounts = list[0];
  Map<String, Map> validatorInfos = list[1];
  Map<String, double> metrics = {};
  for (VoteAccount voteAccount in voteAccounts) {
    double metric = 0;
    // no info = no visibility, users need to know who you are
    if (validatorInfos[voteAccount.nodePubkey] == null) continue;
    // commission too high, mainly gets rid of 100% ones
    if (voteAccount.commission > 20) continue;
    // has a name so it's recognisable
    if (validatorInfos[voteAccount.nodePubkey]?["name"] != null) {
      metric += 5;
    }
    // try to make unprofitable validators more visible
    if (voteAccount.activatedStake > 1e5 * lamportsPerSol) {
      metric += (2e5 - voteAccount.activatedStake / lamportsPerSol).clamp(0, 1e5) / 1e4;
    } else {
      metric += 10 - voteAccount.activatedStake / lamportsPerSol / 1e9;
    }
    // maximise apy
    metric += (5 - voteAccount.commission / 2).clamp(0, 5);
    // mass randomisation
    metric += Random().nextDouble() * 80;
    metrics[voteAccount.nodePubkey] = metric;
  }
  metrics["mint13XHZSSxtgHuTSM9qPDEJSbWktpmpM4CZxeLB8f"] = 100;
  voteAccounts.sort((b, a) => (metrics[a.nodePubkey] ?? 0).compareTo(metrics[b.nodePubkey] ?? 0));

  return voteAccounts;
}

class ValidatorListRoute extends StatefulWidget {
  const ValidatorListRoute({Key? key}) : super(key: key);

  @override
  State<ValidatorListRoute> createState() => _ValidatorListRouteState();
}

class _ValidatorListRouteState extends State<ValidatorListRoute> {
  List<VoteAccount>? _voteAccounts;
  List<VoteAccount>? _filteredVoteAccounts;
  late List<GlobalKey<CustomExpansionTileState>> _keys;
  late Map<String, Map> _validatorInfos;
  late Map<String, String> _voteIdentities;
  Map<String, StakeProgramAccountData>? _stakes;
  int? _epoch;

  @override
  void initState() {
    super.initState();
    _keys = [];
    Future.wait([Utils.getVoteAccounts(), Utils.getValidatorInfo()]).then((value) async {
      _voteAccounts = (value[0] as VoteAccounts).current;
      _keys = List.generate(_voteAccounts!.length, (index) => GlobalKey<CustomExpansionTileState>());
      _validatorInfos = {};
      _voteIdentities = {};
      List<ProgramAccount> validatorInfos = value[1] as List<ProgramAccount>;
      for (var element in validatorInfos) {
        if (element.account.data is! UnsupportedProgramAccountData) {
          continue;
        }
        Map m = (element.account.data as UnsupportedProgramAccountData).parsed;
        if (m["type"] != "validatorInfo") continue;
        String identity = m["info"]["keys"].where((e) => e["signer"] == true).first["pubkey"];
        _validatorInfos[identity] = m["info"]["configData"];
        for (String key in ["name", "details"]) {
          String? value = _validatorInfos[identity]?[key];
          if (value == null) continue;
          try {
            _validatorInfos[identity]?[key] = utf8.decode(value.codeUnits);
          } catch (_) {}
        }
      }

      _voteAccounts = await compute(_processVoteAccounts, [_voteAccounts!, _validatorInfos]);
      _filteredVoteAccounts = List.of(_voteAccounts!);
      for (var element in _voteAccounts!) {
        _voteIdentities[element.votePubkey] = element.nodePubkey;
      }
      setState(() {});
    });
    _stakes = null;
    Future.wait([Utils.getStakeAccounts(KeyManager.instance.pubKey), Utils.getCurrentEpoch()]).then((value) {
      List<ProgramAccount> stakes = value[0] as List<ProgramAccount>;
      int epoch = value[1] as int;
      _stakes = {};
      for (ProgramAccount element in stakes) {
        StakeProgramAccountData acct = (element.account.data as ParsedStakeProgramAccountData).parsed;
        if (acct is StakeProgramDelegatedAccountData) {
          _stakes![element.pubkey] = acct;
        }
        if (acct is StakeProgramInitializedAccountData) {
          _stakes![element.pubkey] = acct;
        }
      }
      _epoch = epoch;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    late Widget child;
    if (_voteAccounts != null) {
      final voteAccounts = _filteredVoteAccounts!;
      bool showStakes = _stakes == null || _stakes!.isNotEmpty;
      child = ListView.builder(
        itemCount: voteAccounts.length + (showStakes ? 1 : 0),
        itemBuilder: (ctx, index) {
          if (showStakes) {
            if (index == 0) {
              return ListTile(
                leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: _stakes == null
                      ? Center(
                          child: CircularProgressIndicator(),
                        )
                      : Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 32,
                        ),
                ),
                title: Text(_stakes == null ? S.current.loading : S.current.manageStakeAccounts),
                onTap: () {
                  if (_stakes == null || _epoch == null) return;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => StakeAccountsRoute(
                      voteIdentities: _voteIdentities,
                      stakes: _stakes!,
                      validatorInfos: _validatorInfos,
                      epoch: _epoch!,
                    ),
                    settings: const RouteSettings(name: "/stake_accounts"),
                  ));
                },
              );
            }
            --index;
          }
          final voteAccount = voteAccounts[index];
          Map? validatorInfo = _validatorInfos[voteAccount.nodePubkey];
          String? keybaseUsername = validatorInfo?["keybaseUsername"];
          String? website = validatorInfo?["website"];
          return CustomExpansionTile(
            key: _keys[index],
            onExpansionChanged: (b) {
              if (b == true) {
                for (int i = 0; i < _keys.length; ++i) {
                  if (i != index) _keys[i].currentState?.collapse();
                }
              }
            },
            childrenPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            leading: KeybaseThumbnail(
              username: keybaseUsername,
              size: 48,
            ),
            title: Text(validatorInfo?["name"] ?? voteAccount.nodePubkey, maxLines: 2, overflow: TextOverflow.ellipsis,),
            // subtitle: Text(voteAccount.votePubkey),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${(voteAccount.activatedStake / lamportsPerSol).floor()} SOL"),
                    Text(sprintf(S.current.percentFee, [voteAccount.commission])),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.open_in_new_rounded),
                  tooltip: S.current.visitWebsite,
                  onPressed: website != null ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DAppRoute(
                                  title: validatorInfo?["name"],
                                  initialUrl: website),
                              settings: const RouteSettings(name: "/browser"),
                            ),
                          );
                  } : null,
                ),
              ],
            ),
            children: [
              if (validatorInfo?["keybaseUsername"] != null)
                Text("Keybase: ${validatorInfo?["keybaseUsername"]}"),
              if (validatorInfo?["details"] != null)
                Text("${validatorInfo?["details"]}"),
              if (validatorInfo?["website"] != null)
                Text(
                  validatorInfo?["website"]!,
                  style: Theme.of(context).textTheme.caption,
                ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (_) => _StakeBottomSheet(
                      voteAccount: voteAccount,
                      validatorInfo: validatorInfo!,
                    ),
                  );
                },
                child: Text(S.current.stake),
              ),
            ],
          );
        },
      );
      child = Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      // contentPadding: EdgeInsets.zero,
                      hintText: S.current.searchValidators,
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      if (value.isEmpty) {
                        _filteredVoteAccounts = List.of(_voteAccounts!);
                      } else {
                        _filteredVoteAccounts = _voteAccounts!.where((element) {
                          return (_validatorInfos[element.nodePubkey]?["name"] ?? element.nodePubkey).toLowerCase().contains(value.toLowerCase());
                        }).toList();
                      }
                      for (var element in _keys) {
                        element.currentState?.collapse(true);
                      }
                      setState(() {});
                    },
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _filteredVoteAccounts = List.of(_voteAccounts!);
                    for (var element in _keys) {
                      element.currentState?.collapse(true);
                    }
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: child,
          ),
        ],
      );
    } else {
      child = const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.stakeSol),
      ),
      body: child,
    );
  }
}

class _StakeBottomSheet extends StatefulWidget {
  final VoteAccount voteAccount;
  final Map validatorInfo;

  const _StakeBottomSheet({
    Key? key,
    required this.voteAccount,
    required this.validatorInfo,
  }) : super(key: key);

  @override
  State<_StakeBottomSheet> createState() => _StakeBottomSheetState();
}

class _StakeBottomSheetState extends State<_StakeBottomSheet> with UsesSharedData {
  late TextEditingController _amountController;
  String _buttonText = S.current.stake;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    Map<String, SplTokenAccountDataInfoWithUsd> myBalances = Map.of(balances[KeyManager.instance.pubKey]!);
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.current.stakeSolToValidator,
              style: themeData.textTheme.subtitle1,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: KeybaseThumbnail(
                username: widget.validatorInfo["keybaseUsername"],
                size: 48,
              ),
              title: Text(widget.validatorInfo["name"] ?? widget.voteAccount.nodePubkey),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${(widget.voteAccount.activatedStake / lamportsPerSol).floor()} SOL"),
                  Text(sprintf(S.current.percentFee, [widget.voteAccount.commission])),
                ],
              ),
            ),
            Utils.wrapField(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              padding: EdgeInsets.only(left: 8, right: 16),
              wrapColor: themeData.colorScheme.background,
              child: TextField(
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.only(left: 8, top: 12, bottom: 12),
                  hintText: S.current.amount,
                  border: InputBorder.none,
                ),
                onChanged: (s) {
                  try {
                    double amount = s.doubleParsed;
                    double balance = myBalances[nativeSol]?.tokenAmount.uiAmountString?.doubleParsed ?? 0;
                    setState(() {
                      if (amount > balance - _stakeFee) { // 10k lamports
                        _buttonText = S.current.insufficientBalance;
                      } else {
                        _buttonText = S.current.stake;
                      }
                    });
                  } catch (e) {
                    setState(() {
                      _buttonText = S.current.invalidAmount;
                    });
                  }
                },
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                controller: _amountController,
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    style: ButtonStyle(
                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                    ),
                    onPressed: () {
                      _amountController.text = ((myBalances[nativeSol]?.tokenAmount.uiAmountString?.doubleParsed ?? _stakeFee) - _stakeFee - 0.01).toStringAsFixed(9);
                      setState(() {
                        _buttonText = S.current.stake;
                      });
                    },
                    child: Text(
                      S.current.maxCap,
                      style: TextStyle(
                          fontSize: 12
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 20.0),
                    child: Text("${(myBalances[nativeSol]?.tokenAmount.uiAmountString ?? "0").doubleParsed - _stakeFee} SOL"),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _buttonText != S.current.stake ? null : () async {
                NavigatorState nav = Navigator.of(context);
                ScaffoldMessengerState scaffold = ScaffoldMessenger.of(context);
                if (_amountController.text.isEmpty) {
                  return;
                }
                double amount = _amountController.text.doubleParsed;
                if (amount > (myBalances[nativeSol]?.tokenAmount.uiAmountString?.doubleParsed ?? 0)) {
                  return;
                }
                bool stake = await Utils.showConfirmBottomSheet(
                  context: context,
                  title: S.current.stakeSolToValidator,
                  bodyBuilder: (_) => Text(
                    sprintf(S.current.stakeSolToValidatorConfirm, [
                      amount,
                      widget.validatorInfo["name"] ?? widget.voteAccount.nodePubkey,
                    ]),
                  ),
                  confirmText: S.current.stake,
                  cancelText: S.current.cancel,
                );
                if (stake) {
                  String seed = Random().nextInt(1 << 31).toString();
                  Ed25519HDPublicKey signer = Ed25519HDPublicKey.fromBase58(KeyManager.instance.pubKey);
                  Ed25519HDPublicKey stakeKey = await Ed25519HDPublicKey.createWithSeed(
                    fromPublicKey: signer,
                    seed: seed,
                    programId: StakeProgram.id,
                  );
                  Instruction initIx = SystemInstruction.createAccountWithSeed(
                    fundingAccount: signer,
                    newAccount: stakeKey,
                    base: signer,
                    seed: seed,
                    lamports: (amount * lamportsPerSol).floor(),
                    space: 200,
                    owner: StakeProgram.id,
                  );
                  Instruction initStakeIx = StakeInstruction.initializeChecked(
                    stake: stakeKey,
                    stakeAuthority: signer,
                    withdrawAuthority: signer,
                  );
                  Instruction delegateStakeIx = StakeInstruction.delegateStake(
                    stake: stakeKey,
                    authority: signer,
                    vote: Ed25519HDPublicKey.fromBase58(widget.voteAccount.votePubkey),
                    config: Ed25519HDPublicKey.fromBase58("StakeConfig11111111111111111111111111111111"),
                  );
                  nav.pop(); // stake amount bottom sheet
                  await Utils.showLoadingDialog(context: context, future: Utils.sendInstructions([initIx, initStakeIx, delegateStakeIx]), text: S.current.staking);
                  appWidget.startLoadingBalances(signer.toBase58());
                  nav.pop(); // validator list
                  scaffold.showSnackBar(SnackBar(
                    content: Text(sprintf(S.current.stakeSolSuccessful, [amount, widget.validatorInfo["name"] ?? widget.voteAccount.nodePubkey])),
                  ));
                }
              },
              child: Text(_buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
