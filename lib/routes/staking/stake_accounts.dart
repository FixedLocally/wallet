import 'package:flutter/material.dart';
import 'package:solana/dto.dart' hide Instruction;
import 'package:solana/solana.dart';

import '../../generated/l10n.dart';
import '../../utils/extensions.dart';
import '../../utils/utils.dart';
import '../../widgets/image.dart';

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
          StakeProgramAccountData stake = widget.stakes.values.elementAt(index);
          StakeDelegatedAccountInfo stakeInfo = (stake as dynamic).info; // i'm done with is checks
          String voteId = stakeInfo.stake.delegation.voter;
          String nodeId = widget.voteIdentities[voteId]!;
          Map? validatorInfo = widget.validatorInfos[nodeId];
          String validatorName = validatorInfo?["name"] ?? nodeId;
          int activationEpoch = stakeInfo.stake.delegation.activationEpoch.intParsed;
          int deactivationEpoch = 69696969;
          try {
            // default is 2^64-1 and it would throw
            deactivationEpoch = stakeInfo.stake.delegation.deactivationEpoch.intParsed;
          } catch (_) {}
          bool activating = activationEpoch >= widget.epoch;
          bool deactivating = deactivationEpoch <= widget.epoch;
          bool inactive = deactivationEpoch < widget.epoch && activationEpoch < widget.epoch;
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
              '${stakeInfo.stake.delegation.stake.doubleParsed / lamportsPerSol} SOL',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(status),
              ],
            ),
            onTap: () async {
              int action = await Utils.showActionBottomSheet(
                context: context,
                title: S.current.stakeAccount,
                actions: [
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
              switch (action) {
                case 0:
                  // unstake
                  break;
                case 1:
                  // redelegate
                  break;
                case 2:
                  // withdraw
                  break;
              }
            },
          );
        },
      ),
    );
  }
}
