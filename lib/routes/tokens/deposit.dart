import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../rpc/key_manager.dart';
import '../../utils/utils.dart';

class DepositTokenRoute extends StatefulWidget {
  const DepositTokenRoute({Key? key}) : super(key: key);

  @override
  State<DepositTokenRoute> createState() => _DepositTokenRouteState();
}

class _DepositTokenRouteState extends State<DepositTokenRoute> {
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
              Utils.wrapField(
                themeData: themeData,
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
              const Text("This address can only be used to receive SOL or SPL tokens on Solana."),
            ],
          ),
        ),
      ),
    );
  }
}
