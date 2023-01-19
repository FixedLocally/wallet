import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bip39/src/wordlists/english.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/services.dart';

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
  late TextSelectionControls _selectionControls;

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
    if (Platform.isIOS) {
      _selectionControls = AppCupertinoTextSelectionControls(
        onPaste: onPaste,
      );
    } else {
      _selectionControls = AppMaterialTextSelectionControls(
        onPaste: onPaste,
      );
    }
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
    } else {
      paste(content);
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
        child: ListView(
          // mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: HighlightedText(text: S.current.seedPhraseWarning),
            ),
            ...List.generate(
              6,
              (index) => Row(
                children: List.generate(
                  2,
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
                          Text("${index * 2 + i + 1}. "),
                          Expanded(
                            child: TextField(
                              controller: _controllers[index * 2 + i],
                              focusNode: _focusNodes[index * 2 + i],
                              selectionControls: _selectionControls,
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
                                ImportAccountsRoute(mnemonic: mnemonic),
                            settings: const RouteSettings(name: "/import"),
                          ),
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

  Future<bool> onPaste(TextSelectionDelegate delegate) {
    return Clipboard.getData(Clipboard.kTextPlain).then((value) {
      print("paste: ${value}");
      if (value != null) {
        return paste(value.text);
      }
      return false;
    });
  }

  bool paste(String? s) {
    if (s == null) return false;
    List<String> words = s.split(" ");
    if (words.length == 12) {
      for (int i = 0; i < 12; ++i) {
        _controllers[i].text = words[i];
      }
      for (final e in _focusNodes) {
        e.unfocus();
      }
      return true;
    }
    return false;
  }
}

class AppCupertinoTextSelectionControls extends CupertinoTextSelectionControls {
  AppCupertinoTextSelectionControls({
    required this.onPaste,
  });
  Future<bool> Function(TextSelectionDelegate) onPaste;

  @override
  Future<void> handlePaste(final TextSelectionDelegate delegate) async {
    if (await onPaste(delegate)) {
      delegate.hideToolbar();
      return;
    } else {
      super.handlePaste(delegate);
    }
  }
}

class AppMaterialTextSelectionControls extends MaterialTextSelectionControls {
  AppMaterialTextSelectionControls({
    required this.onPaste,
  });
  Future<bool> Function(TextSelectionDelegate) onPaste;

  @override
  Future<void> handlePaste(final TextSelectionDelegate delegate) async {
    if (await onPaste(delegate)) {
      delegate.hideToolbar();
      return;
    } else {
      super.handlePaste(delegate);
    }
  }
}
