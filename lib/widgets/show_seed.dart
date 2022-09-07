import 'package:flutter/material.dart';

import '../generated/l10n.dart';

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(S.current.yourSecretRecoveryPhraseIs),
        ...List.generate(4, (index) => Row(
          children: [
            Expanded(child: Text("${index * 3 + 1}. ${widget.mnemonic[index * 3 + 0]}")),
            Expanded(child: Text("${index * 3 + 2}. ${widget.mnemonic[index * 3 + 1]}")),
            Expanded(child: Text("${index * 3 + 3}. ${widget.mnemonic[index * 3 + 2]}")),
          ],
        )),
        Text(S.current.seedPhraseWarning),
      ],
    );
  }
}
