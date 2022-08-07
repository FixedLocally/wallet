import 'dart:async';

import 'package:flutter/material.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:wallet/context_holder.dart';
import 'package:wallet/rpc/constants.dart';

import '../utils/utils.dart';
import 'event.dart';
import 'response.dart';

String _hardcodedWallet = "EpDbR2jE1YB9Tutk36EtKrqz4wZBCwZNMdbHvbqd3TCv";
// String _hardcodedWallet = "GQP9XKoRfwo229MA8iDq8GsC4piAruxrg578QbTNQuqD";
SolanaClient _solanaClient = SolanaClient(rpcUrl: RpcConstants.kRpcUrl, websocketUrl: RpcConstants.kWsUrl);

class RpcServer {
  static final StreamController<RpcEvent> _eventStreamController = StreamController.broadcast();

  static bool _init = false;
  static bool _connected = false;
  static Wallet? _wallet;

  static Stream<RpcEvent> get eventStream => _eventStreamController.stream;

  static Future<RpcResponse> entryPoint(ContextHolder contextHolder, String method, Map args) async {
    if (!_init) await _doInit();
    print("rpcEntryPoint: $method, $args");
    switch (method) {
      case "print":
        return _print(contextHolder, args);
      case "exit":
        return _exit(contextHolder, args);
      case "connect":
        return _connect(contextHolder, args);
      case "disconnect":
        return _disconnect(contextHolder, args);
      case "signTransaction":
        return _signTransaction(contextHolder, args, false);
      case "signAndSendTransaction":
        return _signTransaction(contextHolder, args, true);
    }
    return RpcResponse.error(RpcConstants.kMethodNotFound);
  }

  static Future _doInit() async {
    _wallet = await Wallet.fromPrivateKeyBytes(privateKey: base58decode(_hardcodedKey).sublist(0, 32));
    Signature signature = await _wallet!.sign("solana".codeUnits);
    print(signature);
    print(signature.toBase58());
    _init = true;
  }

  // print a message to the console
  static Future<RpcResponse> _print(ContextHolder contextHolder, Map args) async {
    print("rpcCall: print: ${args["message"]}");
    return RpcResponse.primitive(0);
  }

  // show a "ask for permission" dialog
  static Future<RpcResponse> _exit(ContextHolder contextHolder, Map args) async {
    bool approved = false;
    if (contextHolder.context != null) {
      approved = await _showConfirmDialog(
        context: contextHolder.context!,
        builder: (ctx) {
          return const Text("Exit?");
        },
      );
    }
    if (approved) {
      return RpcResponse.primitive("can exit");
    } else {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }
  }

  // return a pubkey
  static Future<RpcResponse> _connect(ContextHolder contextHolder, Map args) async {
    if (args["onlyIfTrusted"] == true) {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }

    // await Future.delayed(const Duration(milliseconds: 2500));
    _connected = true;
    _eventStreamController.add(RpcEvent.object(
      "connect",
      "PublicKey", [_wallet!.publicKey.toBase58()],
      {
        "publicKey": {"type": "PublicKey", "value": [_wallet!.publicKey.toBase58()]},
        "isConnected": {"type": null, "value": true},
      },
    ));
    return RpcResponse.primitive({
      "publicKey": {"type": "PublicKey", "value": [_wallet!.publicKey.toBase58()]},
    });
  }

  // disconnect wallet
  static Future<RpcResponse> _disconnect(ContextHolder contextHolder, Map args) async {
    _connected = false;
    _eventStreamController.add(RpcEvent.primitive(
      "disconnect",
      null,
      {
        "publicKey": {"type": null, "value": null},
        "isConnected": {"type": null, "value": false},
      },
    ));
    return RpcResponse.primitive(null);
  }

  // sign transaction
  static Future<RpcResponse> _signTransaction(ContextHolder contextHolder, Map args, bool send) async {
    if (contextHolder.disposed) {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }
    if (!_connected) {
      return RpcResponse.error(RpcConstants.kUnauthorized);
    }
    if (args["tx"] == null) {
      return RpcResponse.error(RpcConstants.kInvalidInput);
    }

    List<int> payload = args["tx"].cast<int>();
    CompiledMessage compiledMessage = CompiledMessage(ByteArray(payload));
    Message message = Message.decompile(compiledMessage);

    Future<TokenChanges> simulation = Utils.simulateTx(payload, _wallet!.publicKey.toBase58());
    bool approved = await _showConfirmDialog(
      context: contextHolder.context!,
      builder: (context) {
        return FutureBuilder<TokenChanges>(
          future: simulation,
          builder: (ctx, snapshot) {
            double solOffset = (snapshot.data?.solOffset ?? 0) / lamportsPerSol;
            return Column(
              children: [
                const Text("Approve transaction?"),
                if (snapshot.hasData)
                  ...[
                    ...snapshot.data!.changes.map((key, value) {
                      String mint = snapshot.data!.updatedAccounts[key]!.mint;
                      String symbol = Utils.getToken(mint)?["symbol"] ?? mint;
                      return MapEntry(key, Text("$symbol: ${value > 0 ? "+" : ""}${value.toStringAsFixed(6)}"));
                    }).values,
                    Text("SOL: ${solOffset > 0 ? "+" : ""}${solOffset.toStringAsFixed(6)}"),
                  ]
                else if (snapshot.hasError)
                  Text("Transaction may fail to confirm ${snapshot.error}")
                else
                  const Text("Loading..."),
              ],
            );
          },
        );
      },
    );
    if (approved) {
      String recentBlockhash = args["recentBlockhash"];
      SignedTx signedTx = await _wallet!.signMessage(message: message, recentBlockhash: recentBlockhash);
      print(signedTx.signatures.first.toBase58());
      print(signedTx.encode());
      if (send) {
        try {
          String sig = await _solanaClient.rpcClient.sendTransaction(
              signedTx.encode(), preflightCommitment: Commitment.confirmed);
          return RpcResponse.primitive({
            "signature": {"type": null, "value": sig},
            "publicKey": {
              "type": "PublicKey",
              "value": [_wallet!.publicKey.toBase58()]
            },
          });
        } on JsonRpcException catch (e) {
          return RpcResponse.error(e.code, e.message);
        }
      }
      return RpcResponse.primitive({
        "signature": {"type": null, "value": signedTx.signatures.first.bytes},
        "publicKey": {
          "type": "PublicKey",
          "value": [_wallet!.publicKey.toBase58()]
        },
      });
    } else {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }
  }
}

Future<bool> _showConfirmDialog({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  bool? result = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            builder(ctx),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: const Text("Yes"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text("No"),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}