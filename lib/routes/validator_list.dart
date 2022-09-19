import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:sprintf/sprintf.dart';

import '../generated/l10n.dart';
import '../utils/utils.dart';
import '../widgets/image.dart';

Future<List<VoteAccount>> _processVoteAccounts(List list) async {
  List<VoteAccount> voteAccounts = list[0];
  Map<String, Map> validatorInfos = list[1];
  VoteAccount mint = voteAccounts.firstWhere((element) => element.nodePubkey == "mint13XHZSSxtgHuTSM9qPDEJSbWktpmpM4CZxeLB8f");
  // remove mint
  voteAccounts.remove(mint);
  // remove those without info or commission>20%
  voteAccounts.removeWhere((element) => validatorInfos[element.nodePubkey] == null || element.commission > 20);
  // shuffle
  voteAccounts.shuffle();
  // add mint back
  voteAccounts.insert(0, mint);
  return voteAccounts;
}

class ValidatorListRoute extends StatefulWidget {
  const ValidatorListRoute({Key? key}) : super(key: key);

  @override
  State<ValidatorListRoute> createState() => _ValidatorListRouteState();
}

class _ValidatorListRouteState extends State<ValidatorListRoute> {
  List<VoteAccount>? _voteAccounts;
  late Map<String, Map> _validatorInfos;

  @override
  void initState() {
    super.initState();
    Future.wait([Utils.getVoteAccounts(), Utils.getValidatorInfo()]).then((value) async {
      _voteAccounts = (value[0] as VoteAccounts).current;
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
      });

      _voteAccounts = await compute(_processVoteAccounts, [_voteAccounts!, _validatorInfos]);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    late Widget child;
    if (_voteAccounts != null) {
      final voteAccounts = _voteAccounts!;
      child = ListView.builder(
        itemCount: voteAccounts.length,
        itemBuilder: (ctx, index) {
          final voteAccount = voteAccounts[index];
          Map? validatorInfo = _validatorInfos[voteAccount.nodePubkey];
          String? keybaseUsername = validatorInfo?["keybaseUsername"];
          return ListTile(
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
            title: Text(validatorInfo?["name"] ?? voteAccount.nodePubkey),
            subtitle: Text(voteAccount.votePubkey),
            trailing: Column(
              children: [
                Text("${(voteAccount.activatedStake / lamportsPerSol).floor()} SOL"),
                Text(sprintf(S.current.percentFee, [voteAccount.commission])),
              ],
            ),
          );
        },
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
