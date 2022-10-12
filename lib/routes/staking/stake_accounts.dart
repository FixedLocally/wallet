import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solana/dto.dart' hide Instruction;
import 'package:solana/solana.dart';

import '../../generated/l10n.dart';
import '../../rpc/key_manager.dart';
import '../../utils/extensions.dart';
import '../../utils/utils.dart';
import '../../widgets/bottom_sheet.dart';
import '../../widgets/image.dart';
import '../webview.dart';

class StakeAccountsRoute extends StatefulWidget {
  final Map<String, StakeProgramAccountData> stakes;
  final Map<String, Map> validatorInfos;
  final Map<String, String> voteIdentities;
  final int epoch;

  const StakeAccountsRoute({
    Key? key,
    required this.stakes,
    required this.validatorInfos,
    required this.voteIdentities,
    required this.epoch,
  }) : super(key: key);

  @override
  State<StakeAccountsRoute> createState() => _StakeAccountsRouteState();
}

class _StakeAccountsRouteState extends State<StakeAccountsRoute> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.stakeAccounts),
      ),
      body: ListView.builder(
        itemCount: widget.stakes.length,
        itemBuilder: (context, index) {
          NavigatorState nav = Navigator.of(context);
          ScaffoldMessengerState scaffold = ScaffoldMessenger.of(context);
          String stakeKey = widget.stakes.keys.elementAt(index);
          StakeProgramAccountData stake = widget.stakes.values.elementAt(index);
          StakeDelegatedAccountInfo stakeInfo = (stake as dynamic).info; // i'm done with is checks
          String voteId = stakeInfo.stake.delegation.voter;
          String nodeId = widget.voteIdentities[voteId]!;
          Map? validatorInfo = widget.validatorInfos[nodeId];
          String validatorName = validatorInfo?["name"] ?? nodeId;
          int activationEpoch = stakeInfo.stake.delegation.activationEpoch.intParsed;
          int deactivationEpoch = 696969;
          try {
            // default is 2^64-1 and it would throw
            deactivationEpoch = stakeInfo.stake.delegation.deactivationEpoch.intParsed;
          } catch (_) {}
          bool activating = activationEpoch >= widget.epoch;
          bool deactivating = deactivationEpoch <= widget.epoch;
          bool inactive = deactivationEpoch < widget.epoch && activationEpoch < widget.epoch || activating && deactivating;
          if (inactive) {
            activating = false;
          }
          String status = S.current.active;
          if (inactive) {
            status = S.current.inactive;
          } else if (activating) {
            status = S.current.activating;
          } else if (deactivating) {
            status = S.current.deactivating;
          }
          return ListTile(
            leading: KeybaseThumbnail(
              username: validatorInfo?["keybaseUsername"],
              size: 40,
            ),
            title: Text(validatorName),
            subtitle: Text(
              '${stakeInfo.stake.delegation.stake.doubleParsed / lamportsPerSol} SOL / ${stakeKey.shortened}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(status),
              ],
            ),
            onTap: () async {
              int action = await showActionBottomSheet(
                context: context,
                title: S.current.stakeAccount,
                actions: [
                  BottomSheetAction(title: S.current.copyAddress, value: 100),
                  BottomSheetAction(title: S.current.viewOnSolscan, value: 101),
                  if (!inactive && !deactivating && !activating)
                    BottomSheetAction(title: S.current.startUnstaking, value: 0),
                  if (activating)
                    BottomSheetAction(title: S.current.unstake, value: 0),
                  if (inactive || deactivating)
                    BottomSheetAction(title: S.current.redelegate, value: 1),
                  if (inactive)
                    BottomSheetAction(title: S.current.withdraw, value: 2),
                ],
              );
              late Future f;
              switch (action) {
                case 0:
                  // unstake
                  f = Utils.sendInstructions([
                    StakeInstruction.deactivate(
                      stake: Ed25519HDPublicKey.fromBase58(stakeKey),
                      authority: Ed25519HDPublicKey.fromBase58(KeyManager.instance.pubKey),
                    ),
                  ]);
                  break;
                case 1:
                  // redelegate
                  f = Utils.sendInstructions([
                    StakeInstruction.delegateStake(
                      stake: Ed25519HDPublicKey.fromBase58(stakeKey),
                      vote: Ed25519HDPublicKey.fromBase58(voteId),
                      authority: Ed25519HDPublicKey.fromBase58(KeyManager.instance.pubKey),
                      config: Ed25519HDPublicKey.fromBase58("StakeConfig11111111111111111111111111111111"),
                    ),
                  ]);
                  break;
                case 2:
                  // withdraw
                  int lamports = stakeInfo.stake.delegation.stake.intParsed + stakeInfo.meta.rentExemptReserve.intParsed;
                  f = Utils.sendInstructions([
                    StakeInstruction.withdraw(
                      stake: Ed25519HDPublicKey.fromBase58(stakeKey),
                      authority: Ed25519HDPublicKey.fromBase58(KeyManager.instance.pubKey),
                      recipient: Ed25519HDPublicKey.fromBase58(KeyManager.instance.pubKey),
                      lamports: lamports,
                    ),
                  ]);
                  break;
                case 100:
                  Clipboard.setData(
                    ClipboardData(text: stakeKey),
                  );
                  scaffold.showSnackBar(
                    SnackBar(
                      content: Text(S.current.addressCopied),
                    ),
                  );
                  break;
                case 101:
                  nav.push(MaterialPageRoute(
                    builder: (context) => DAppRoute(
                      title: "",
                      initialUrl: "https://solscan.io/account/$stakeKey",
                    ),
                  ));
                  break;
                default:
                  f = Future.value(null);
                  break;
              }
              // there is actual action
              if (action < 100) {
                await Utils.showLoadingDialog(context: context, future: f);
                if (action != 2) {
                  Account acct = (await Utils.getAccount(
                    stakeKey,
                    encoding: Encoding.jsonParsed,
                    commitment: Commitment.processed,
                  ))!;
                  setState(() {
                    widget.stakes[stakeKey] =
                        (acct.data as ParsedStakeProgramAccountData).parsed;
                  });
                } else {
                  // withdrawn stakes are gone for good
                  setState(() {
                    widget.stakes.remove(stakeKey);
                  });
                }
              }
            },
          );
        },
      ),
    );
  }
}
