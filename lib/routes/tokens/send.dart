import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart' hide Instruction;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../../rpc/key_manager.dart';
import '../../utils/utils.dart';
import '../../widgets/image.dart';


class SendTokenRoute extends StatefulWidget {
  final SplTokenAccountDataInfoWithUsd balance;
  final Map<String, dynamic> tokenDetails;

  const SendTokenRoute({
    Key? key,
    required this.balance,
    required this.tokenDetails,
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
    String symbol = widget.tokenDetails["symbol"] ?? "";
    return Scaffold(
      appBar: AppBar(
        title: Text('Send $symbol'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                MultiImage(image: widget.tokenDetails["image"] ?? "", size: 128),
                const SizedBox(height: 16),
                Utils.wrapField(
                  themeData: themeData,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _addressController,
                          validator: (value) {
                            List<int> data = base58decode(value ?? "");
                            if (data.length != 32) return "Invalid address";
                            return null;
                          },
                          decoration: const InputDecoration(
                            hintText: "Recipient",
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
                        icon: Icon(Icons.paste, color: themeData.colorScheme.onBackground,),
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
                Utils.wrapField(
                  themeData: themeData,
                  child: TextFormField(
                    validator: (value) {
                      double amt = double.tryParse(value ?? "") ?? 0;
                      if (amt <= 0) return "Invalid amount";
                      if (amt > double.parse(widget.balance.tokenAmount.uiAmountString!)) return "Insufficient funds";
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: "Amount",
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
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "${widget.balance.tokenAmount.uiAmountString} $symbol",
                    style: themeData.textTheme.subtitle2,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    ScaffoldMessengerState scaffold = ScaffoldMessenger.of(context);
                    NavigatorState navigator = Navigator.of(context);
                    if (_formKey.currentState!.validate()) {
                      bool confirm = await Utils.showConfirmDialog(
                        context: context,
                        title: "Send $symbol",
                        content: "You are about to send $_amount $symbol to $_recipient.",
                      );
                      if (confirm) {
                        Completer completer = Completer();
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
                          Utils.sendInstructions(ixs).then((value) => completer.complete(value));
                          await Utils.showLoadingDialog(
                            context: context,
                            future: completer.future,
                            text: "Sending...",
                          );
                          navigator.pop(true);
                          scaffold.showSnackBar(
                            const SnackBar(
                              content: Text("Transaction sent"),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: Text(
                    "Send",
                    style: themeData.textTheme.button,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
