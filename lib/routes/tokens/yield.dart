import 'package:flutter/material.dart';

import '../../models/models.dart';

class YieldDepositRoute extends StatefulWidget {
  final YieldOpportunity opportunity;

  const YieldDepositRoute({
    super.key,
    required this.opportunity,
  });

  @override
  State<YieldDepositRoute> createState() => _YieldDepositRouteState();
}

class _YieldDepositRouteState extends State<YieldDepositRoute> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yield Deposit'),
      ),
    );
  }
}
