import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../generated/l10n.dart';
import '../home.dart';
import '../../rpc/key_manager.dart';
import '../../utils/utils.dart';
import '../../widgets/text.dart';

class GenerateSeedRoute extends StatefulWidget {
  final List<String> mnemonic;

  const GenerateSeedRoute({Key? key, required this.mnemonic}) : super(key: key);

  @override
  State<GenerateSeedRoute> createState() => _GenerateSeedRouteState();
}

class _GenerateSeedRouteState extends State<GenerateSeedRoute> {
  @override
  void initState() {
    super.initState();
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
              6,
              (index) => Row(
                children: List.generate(
                  2,
                  (i) => Expanded(
                    child: Utils.wrapField(
                      wrapColor: Theme.of(context).cardColor,
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(16),
                      // decoration: BoxDecoration(
                      //   border: Border.all(
                      //     color: theme.cardColor,
                      //   ),
                      // ),
                      child: Text(
                          "${index * 2 + i + 1}. ${widget.mnemonic[index * 2 + i]}"),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    child: Text(S.current.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.mnemonic.join(" ")));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(S.current.copySeedSuccess),
                      ));
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    child: Text(S.current.continuE),
                    onPressed: () async {
                      await KeyManager.instance.insertSeed(widget.mnemonic.join(" "));
                      if (mounted) {
                        Navigator.of(context).pop(); // the dialog
                        // replace setup route
                        Navigator.pushReplacement(context, MaterialPageRoute(
                          builder: (ctx) {
                            return const HomeRoute();
                          },
                        ));
                      }
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
