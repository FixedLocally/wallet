import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../rpc/key_manager.dart';

class DepositRoute extends StatefulWidget {
  const DepositRoute({Key? key}) : super(key: key);

  @override
  State<DepositRoute> createState() => _DepositRouteState();
}

class _DepositRouteState extends State<DepositRoute> {
  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deposit'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: QrImage(
                  data: KeyManager.instance.pubKey,
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 16, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: themeData.colorScheme.background,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        KeyManager.instance.pubKey,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: KeyManager.instance.pubKey),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Address copied"),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
              ),
              Text("This address can only be used to receive SOL or SPL tokens on Solana."),
            ],
          ),
        ),
      ),
    );
  }
}
