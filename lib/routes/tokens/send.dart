import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart' hide Instruction;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:sprintf/sprintf.dart';

import '../../generated/l10n.dart';
import '../../rpc/key_manager.dart';
import '../../utils/utils.dart';
import '../../widgets/image.dart';
import '../image.dart';


class SendTokenRoute extends StatefulWidget {
  final SplTokenAccountDataInfoWithUsd balance;
  final Map<String, dynamic> tokenDetails;
  final bool nft;

  const SendTokenRoute({
    Key? key,
    required this.balance,
    required this.tokenDetails,
    this.nft = false,
  }) : super(key: key);

  @override
  State<SendTokenRoute> createState() => _SendTokenRouteState();
}

class _SendTokenRouteState extends State<SendTokenRoute> {
  late Map<String, dynamic> _tokenDetails;
  late GlobalKey<FormState> _formKey;
  late TextEditingController _addressController;

  String _recipient = "";
  String _amount = "";

  String? _recipientError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _tokenDetails = widget.tokenDetails;
    _formKey = GlobalKey();
    _addressController = TextEditingController();
    if (_tokenDetails.isEmpty) {
      Utils.getToken(widget.balance.mint).then((value) {
        setState(() {
          _tokenDetails = value ?? {};
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    MediaQueryData mq = MediaQuery.of(context);
    String symbol = widget.tokenDetails["symbol"] ?? "";
    Widget img = MultiImage(
      image: widget.tokenDetails["image"] ?? "",
      size: widget.nft ? min(mq.size.width * 0.75, 400) : 128,
      borderRadius: widget.nft ? 16 : null,
    );
    if (widget.nft) {
      img = GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageRoute(
                image: widget.tokenDetails["image"],
              ),
            ),
          );
        },
        child: img,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Send $symbol'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                img,
                const SizedBox(height: 16),
                Utils.wrapField(
                  themeData: themeData,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            hintText: S.current.recipient,
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _recipient = value;
                            });
                          },
                        ),
                      ),
                      IconButton(
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.paste,
                          color: themeData.colorScheme.onBackground,
                        ),
                        onPressed: () {
                          Clipboard.getData(Clipboard.kTextPlain).then((value) {
                            setState(() {
                              _addressController.text = value?.text ?? "";
                              _recipient = _addressController.text;
                            });
                          });
                        },
                      )
                    ],
                  ),
                ),
                if (_recipientError != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _recipientError!,
                      style: (themeData.textTheme.caption ?? const TextStyle())
                          .copyWith(color: themeData.colorScheme.error),
                    ),
                  ),
                Utils.wrapField(
                  themeData: themeData,
                  child: TextFormField(
                    decoration: InputDecoration(
                      hintText: S.current.amount,
                      border: InputBorder.none,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      setState(() {
                        _amount = value;
                      });
                    },
                  ),
                ),
                if (_amountError != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _amountError!,
                      style: (themeData.textTheme.caption ?? const TextStyle())
                          .copyWith(color: themeData.colorScheme.error),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "${widget.balance.tokenAmount.uiAmountString} $symbol",
                    style: themeData.textTheme.subtitle2,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          ScaffoldMessengerState scaffold = ScaffoldMessenger.of(context);
                          NavigatorState navigator = Navigator.of(context);
                          if (_validate()) {
                            bool confirm = await Utils.showConfirmBottomSheet(
                              context: context,
                              title: sprintf(S.current.sendToken, [symbol]),
                              bodyBuilder: (_) => Text("You are about to send $_amount $symbol to $_recipient."), // todo
                            );
                            if (confirm) {
                              Completer<String> completer = Completer();
                              List<Instruction> ixs = [];
                              if (widget.balance.mint == nativeSol) {
                                ixs.add(SystemInstruction.transfer(
                                  fundingAccount: Ed25519HDPublicKey.fromBase58(KeyManager.instance.pubKey),
                                  recipientAccount: Ed25519HDPublicKey.fromBase58(_recipient),
                                  lamports: (double.parse(_amount) * lamportsPerSol).floor(),
                                ));
                              } else {
                                // check if destination exists
                                Ed25519HDPublicKey recipient = Ed25519HDPublicKey.fromBase58(_recipient);
                                Ed25519HDPublicKey mint = Ed25519HDPublicKey.fromBase58(widget.balance.mint);
                                Ed25519HDPublicKey destTokenAcct = await findAssociatedTokenAddress(
                                  owner: recipient,
                                  mint: mint,
                                );
                                Account? acct = await Utils.getAccount(destTokenAcct.toBase58());
                                if (acct == null) {
                                  ixs.add(AssociatedTokenAccountInstruction.createAccount(
                                    funder: Ed25519HDPublicKey.fromBase58(KeyManager.instance.pubKey),
                                    address: destTokenAcct,
                                    owner: recipient,
                                    mint: mint,
                                  ));
                                }
                                ixs.add(TokenInstruction.transfer(
                                  owner: Ed25519HDPublicKey.fromBase58(KeyManager.instance.pubKey),
                                  destination: destTokenAcct,
                                  amount: (double.parse(_amount) * pow(10, _tokenDetails["decimals"])).floor(),
                                  source: Ed25519HDPublicKey.fromBase58(widget.balance.account),
                                ));
                              }
                              if (mounted) {
                                Utils.sendInstructions(ixs).then((value) => completer.complete(value)).catchError((_) => completer.complete(""));
                                String tx = await Utils.showLoadingDialog(
                                  context: context,
                                  future: completer.future,
                                  text: "Sending...",
                                );
                                if (tx.isNotEmpty) {
                                  navigator.pop(true);
                                  scaffold.showSnackBar(
                                    SnackBar(
                                      content: Text(S.current.txConfirmed),
                                    ),
                                  );
                                } else {
                                  scaffold.showSnackBar(
                                    SnackBar(
                                      content: Text(S.current.errorSendingTxs),
                                    ),
                                  );
                                }
                              }
                            }
                          }
                        },
                        child: Text(
                          S.current.send,
                          style: themeData.textTheme.button,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _validate() {
    // validate amount
    _amountError = null;
    _recipientError = null;
    double amt = double.tryParse(_amount) ?? 0;
    if (amt <= 0) _amountError = S.current.invalidAmount;
    if (amt > double.parse(widget.balance.tokenAmount.uiAmountString!)) _amountError = S.current.insufficientFunds;
    // validate recipient
    List<int> data = base58decode(_recipient);
    if (data.length != 32) _recipientError = S.current.invalidAddress;
    setState(() {});
    return _recipientError == null && _amountError == null;
  }
}
