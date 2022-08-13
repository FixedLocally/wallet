import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../../rpc/key_manager.dart';
import '../../utils/utils.dart';


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
                CircleAvatar(
                  radius: 64,
                  backgroundColor: Colors.white,
                  backgroundImage: CachedNetworkImageProvider(
                    widget.tokenDetails["image"] ?? "",
                  ),
                ),
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
                        Instruction ix = SystemInstruction.transfer(
                          fundingAccount: Ed25519HDPublicKey.fromBase58(
                                KeyManager.instance.pubKey),
                          recipientAccount: Ed25519HDPublicKey.fromBase58(
                                _recipient),
                          lamports: (double.parse(_amount) * lamportsPerSol).floor(),
                        );
                        if (mounted) {
                          await Utils.showLoadingDialog(
                            context: context,
                            future: Utils.sendInstruction(ix),
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
