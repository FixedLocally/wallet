import 'package:flutter/material.dart';
import 'package:bip39/src/wordlists/english.dart';
import 'package:bip39/bip39.dart' as bip39;

import '../../generated/l10n.dart';
import '../../utils/utils.dart';
import '../../widgets/text.dart';
import 'restore_accounts.dart';

class RestoreSeedRoute extends StatefulWidget {
  const RestoreSeedRoute({Key? key}) : super(key: key);

  @override
  State<RestoreSeedRoute> createState() => _RestoreSeedRouteState();
}

class _RestoreSeedRouteState extends State<RestoreSeedRoute> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(12, (index) => FocusNode());
    _controllers = List.generate(12, (index) {
      TextEditingController controller = TextEditingController();
      controller.addListener(() {
        _checkWord(index);
      });
      return controller;
    });
  }

  void _checkWord(int index) {
    String content = _controllers[index].text;
    if (content.endsWith(" ")) {
      content = content.trim();
      if (WORDLIST.contains(content)) {
        _controllers[index].text = content;
        _controllers[index].selection = TextSelection.fromPosition(TextPosition(offset: content.length));
        if (index < 11) {
          FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
        } else {
          FocusScope.of(context).unfocus();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.yourSecretRecoveryPhraseIs),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: HighlightedText(text: S.current.seedPhraseWarning),
            ),
            ...List.generate(
              4,
              (index) => Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Utils.wrapField(
                      wrapColor: Theme.of(context).cardColor,
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // decoration: BoxDecoration(
                      //   border: Border.all(
                      //     color: theme.cardColor,
                      //   ),
                      // ),
                      child: Row(
                        children: [
                          Text("${index * 3 + i + 1}. "),
                          Expanded(
                            child: TextField(
                              controller: _controllers[index * 3 + i],
                              focusNode: _focusNodes[index * 3 + i],
                              decoration: InputDecoration(
                                border: InputBorder.none,
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    child: Text(S.current.continuE),
                    onPressed: () async {
                      String mnemonic = _controllers.map((e) => e.text).join(" ");
                      bool valid = bip39.validateMnemonic(mnemonic);
                      if (!valid) {
                        Utils.showInfoDialog(
                          context: context,
                          title: S.current.invalidSeed,
                          content: S.current.invalidSeedContent,
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) =>
                              ImportAccountsRoute(mnemonic: mnemonic)),
                        );
                      }
                      // await KeyManager.instance.insertSeed(widget.mnemonic.join(" "));
                      // if (mounted) {
                      //   Navigator.of(context).pop(); // the dialog
                      //   // replace setup route
                      //   Navigator.pushReplacement(context, MaterialPageRoute(
                      //     builder: (ctx) {
                      //       return const HomeRoute();
                      //     },
                      //   ));
                      // }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
