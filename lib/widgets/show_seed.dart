import 'package:flutter/material.dart';

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
        const Text('Your secret recovery phrase is:'),
        ...List.generate(4, (index) => Row(
          children: [
            Expanded(child: Text("${index * 3 + 1}. ${widget.mnemonic[index * 3 + 0]}")),
            Expanded(child: Text("${index * 3 + 2}. ${widget.mnemonic[index * 3 + 1]}")),
            Expanded(child: Text("${index * 3 + 3}. ${widget.mnemonic[index * 3 + 2]}")),
          ],
        )),
        const Text('Your secret recovery phrase is the ONE and ONLY way to access your wallet. DO NOT share it with anyone.'),
      ],
    );
  }
}
