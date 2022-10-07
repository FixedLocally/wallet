import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:solana/solana.dart';

import '../generated/l10n.dart';

class QrScannerRoute extends StatefulWidget {
  const QrScannerRoute({Key? key}) : super(key: key);

  @override
  State<QrScannerRoute> createState() => _QrScannerRouteState();
}

class _QrScannerRouteState extends State<QrScannerRoute> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.scanQrCode),
      ),
      body: MobileScanner(
        onDetect: (Barcode code, MobileScannerArguments? args) {
          String value = code.rawValue ?? "";
          try {
            Ed25519HDPublicKey.fromBase58(value);
            Navigator.pop(context, value);
          } catch (_) {} // what, just not a pubkey, try again
        },
      ),
    );
  }
}
