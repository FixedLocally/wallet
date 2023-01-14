import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:sprintf/sprintf.dart';

import '../../generated/l10n.dart';
import '../../models/models.dart';
import '../../rpc/key_manager.dart';
import '../../utils/extensions.dart';
import '../../utils/utils.dart';
import '../../widgets/approve_tx.dart';
import '../mixins/inherited.dart';

class YieldDepositRoute extends StatefulWidget {
  final YieldOpportunity opportunity;
  final SplTokenAccountDataInfoWithUsd account;
  final String mint;
  final String symbol;
  final int decimals;

  const YieldDepositRoute({
    super.key,
    required this.opportunity,
    required this.account,
    required this.mint,
    required this.symbol,
    required this.decimals,
  });

  @override
  State<YieldDepositRoute> createState() => _YieldDepositRouteState();
}

class _YieldDepositRouteState extends State<YieldDepositRoute> with UsesSharedData {
  late TextEditingController _amountController;
  bool _amountValid = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.yield),
      ),
      body: TextButtonTheme(
        data: TextButtonThemeData(
          style: TextButton.styleFrom(
            primary: theme.colorScheme.onPrimary,
            backgroundColor: theme.colorScheme.primary,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            textStyle: theme.textTheme.button?.copyWith(
              color: theme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(width: 16),
                SizedBox(
                  width: 64,
                  child: Text(S.current.deposit),
                ),
                Expanded(
                  child: Utils.wrapField(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    padding: EdgeInsets.fromLTRB(8, 10, 16, 10),
                    wrapColor: theme.colorScheme.background,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.only(left: 8),
                              hintText: "0.00",
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              setState(() {
                                try {
                                  _amountController.text.doubleParsed;
                                  _amountValid = true;
                                } catch (e) {
                                  _amountValid = false;
                                }
                              });
                            },
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            controller: _amountController,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 16),
              ],
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${widget.account.tokenAmount.uiAmountString ?? "0"} ${widget.symbol}"),
                  SizedBox(width: 8),
                  TextButton(
                    style: ButtonStyle(
                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                    ),
                    onPressed: () {
                      double amt = (widget.account.tokenAmount.uiAmountString?.doubleParsed ?? 0) / 2;
                      _amountController.text = amt.toFixedTrimmed(widget.decimals);
                      setState(() {
                        _amountValid = amt > 0;
                      });
                    },
                    child: Text(
                      S.current.halfCap,
                      style: TextStyle(
                          fontSize: 12
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  TextButton(
                    style: ButtonStyle(
                      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                    ),
                    onPressed: () {
                      double bal = widget.account.tokenAmount.uiAmountString?.doubleParsed ?? 0;
                      if (widget.mint == nativeSol) {
                        bal -= 0.01;
                        bal = bal.clamp(0, double.infinity);
                      }
                      _amountController.text = bal.toFixedTrimmed(widget.decimals);
                      setState(() {
                        _amountValid = bal > 0;
                      });
                    },
                    child: Text(
                      S.current.maxCap,
                      style: TextStyle(
                          fontSize: 12
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _amountValid ? () async {
                String pubkey = KeyManager.instance.pubKey;
                NavigatorState nav = Navigator.of(context);
                ScaffoldMessengerState scaffold = ScaffoldMessenger.of(context);
                int amt = (_amountController.text.doubleParsed * pow(10, widget.decimals)).floor();
                Completer completer = Completer();
                List<List<int>> txs = await Utils.showLoadingDialog(
                  context: context,
                  future: widget.opportunity
                      .getTxs(KeyManager.instance.pubKey, amt),
                );
                Future<List<TokenChanges>> simulation = Utils.simulateTxs(txs.map((e) => e.sublist(65)).toList(), KeyManager.instance.pubKey, [-1]);
                bool approved = await Utils.showConfirmBottomSheet(
                  context: context,
                  confirmText: S.current.approve,
                  cancelText: S.current.cancel,
                  bodyBuilder: (context) {
                    return ApproveTransactionWidget(simulation: simulation);
                  },
                );
                if (approved) {
                  Utils.showLoadingDialog(
                    context: context,
                    future: completer.future,
                  );
                  RecentBlockhash bh = await Utils.getBlockhash();
                  for (List<int> tx in txs) {
                    CompiledMessage compiledMessage = CompiledMessage(ByteArray(tx.sublist(65)));
                    Message message = Message.decompile(compiledMessage);
                    SignedTx signedTx = await KeyManager.instance.signMessage(message, bh.blockhash);
                    await Utils.sendTransaction(signedTx);
                  }
                  appWidget.startLoadingBalances(pubkey);
                  await balancesCompleters[pubkey]!.future;
                  completer.complete();
                  nav.pop();
                  scaffold.showSnackBar(SnackBar(content: Text(sprintf(S.current.yieldDepositSuccess, [widget.opportunity.apy.toStringAsFixed(2), _amountController.text, widget.symbol]))));
                }

              } : null,
              child: Text(sprintf(S.current.startEarningBtn, [widget.opportunity.apy.toStringAsFixed(2)])),
            )
          ],
        ),
      ),
    );
  }
}
