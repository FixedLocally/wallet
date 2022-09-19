import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:sprintf/sprintf.dart';

import '../generated/l10n.dart';
import '../utils/utils.dart';
import '../widgets/custom_expansion_tile.dart';
import '../widgets/image.dart';
import 'webview.dart';

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

  @override
  void initState() {
    super.initState();
    _keys = [];
    Future.wait([Utils.getVoteAccounts(), Utils.getValidatorInfo()]).then((value) async {
      _voteAccounts = (value[0] as VoteAccounts).current;
      _keys = List.generate(_voteAccounts!.length, (index) => GlobalKey<CustomExpansionTileState>());
      _validatorInfos = {};
      List<ProgramAccount> validatorInfos = value[1] as List<ProgramAccount>;
      validatorInfos.forEach((element) {
        if (element.account.data is! UnsupportedProgramAccountData) {
          print(element.pubkey);
          return;
        }
        Map m = (element.account.data as UnsupportedProgramAccountData).parsed;
        if (m["type"] != "validatorInfo") return;
        String identity = m["info"]["keys"].where((e) => e["signer"] == true).first["pubkey"];
        _validatorInfos[identity] = m["info"]["configData"];
        for (String key in ["name", "details"]) {
          String? value = _validatorInfos[identity]?[key];
          if (value == null) continue;
          _validatorInfos[identity]?[key] = utf8.decode(value.codeUnits);
        }
      });

      _voteAccounts = await compute(_processVoteAccounts, [_voteAccounts!, _validatorInfos]);
      _filteredVoteAccounts = List.of(_voteAccounts!);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    late Widget child;
    if (_voteAccounts != null) {
      final voteAccounts = _filteredVoteAccounts!;
      child = ListView.builder(
        itemCount: voteAccounts.length,
        itemBuilder: (ctx, index) {
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
            leading: keybaseUsername != null
                ? KeybaseThumbnail(
              username: keybaseUsername,
              size: 48,
            )
                : Image.asset(
              "assets/images/unknown.png",
              width: 48,
              height: 48,
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
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DAppRoute(title: validatorInfo?["name"], initialUrl: website)));
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
                      hintText: S.current.searchTokensOrPasteAddress,
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
        title: const Text('Validator List'),
      ),
      body: child,
    );
  }
}
