import 'dart:async';

import 'package:flutter/material.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:wallet/routes/mixins/context_holder.dart';
import 'package:wallet/rpc/constants.dart';
import 'package:wallet/widgets/approve_tx.dart';

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
  static bool get connected => _connected;

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
      case "signAllTransactions":
        return _signAllTransactions(contextHolder, args, false);
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
    RpcResponse? error = _sigPreChecks(contextHolder);
    if (error != null) {
      return error;
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
        return ApproveTransactionWidget(simulation: simulation);
      },
    );
    if (approved) {
      String recentBlockhash = args["recentBlockhash"];
      SignedTx signedTx = await _wallet!.signMessage(message: message, recentBlockhash: recentBlockhash);
      print(signedTx.signatures.first.toBase58());
      Signature signature = await _wallet!.sign(payload);
      print(signedTx.encode());
      print(signature.toBase58());
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
        "signature": {"type": null, "value": signature.bytes},
        "publicKey": {
          "type": "PublicKey",
          "value": [_wallet!.publicKey.toBase58()]
        },
      });
    } else {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }
  }

  // sign all transactions
  static Future<RpcResponse> _signAllTransactions(ContextHolder contextHolder, Map args, bool send) async {
    // {"txs": [{"tx", "recentBlockhash"}]}
    RpcResponse? error = _sigPreChecks(contextHolder);
    if (error != null) {
      return error;
    }
    if (args["txs"] == null) return RpcResponse.error(RpcConstants.kInvalidInput);
    List<Map<String, dynamic>> txs = args["txs"]!.cast<Map<String, dynamic>>();

    List<CompiledMessage> compiledMessages = [];
    List<Message> messages = [];
    List<List<int>> payloads = [];
    List<String> blockhashes = [];
    txs.forEach((e) {
      List<int> payload = e["tx"].cast<int>();
      CompiledMessage compiledMessage = CompiledMessage(ByteArray(payload));
      Message message = Message.decompile(compiledMessage);
      compiledMessages.add(compiledMessage);
      messages.add(message);
      payloads.add(payload);
      blockhashes.add(e["recentBlockhash"]);
    });

    Future<TokenChanges> simulation = Utils.simulateTxs(payloads, _wallet!.publicKey.toBase58());
    bool approved = await _showConfirmDialog(
      context: contextHolder.context!,
      builder: (context) {
        return ApproveTransactionWidget(simulation: simulation);
      },
    );
    if (approved) {
      List<SignedTx> signedTxs = [];
      List<Signature> signatures = [];
      for (int i = 0; i < payloads.length; ++i) {
        String recentBlockhash = blockhashes[i];
        SignedTx signedTx = await _wallet!.signMessage(message: messages[i], recentBlockhash: recentBlockhash);
        Signature signature = await _wallet!.sign(payloads[i]);
        signedTxs.add(signedTx);
        signatures.add(signature);
        print(signedTx.signatures.first.toBase58());
        print(signedTx.encode());
        print(signature.toBase58());
      }

      if (send) {
        try {
          List<String> sigs = [];
          for (SignedTx signedTx in signedTxs) {
            String sig = await _solanaClient.rpcClient.sendTransaction(
                signedTx.encode(), preflightCommitment: Commitment.confirmed);
            sigs.add(sig);
          }
          return RpcResponse.primitive(sigs.map((e) => {
            "signature": {"type": null, "value": e},
            "publicKey": {
              "type": "PublicKey",
              "value": [_wallet!.publicKey.toBase58()]
            },
          }).toList());
        } on JsonRpcException catch (e) {
          return RpcResponse.error(e.code, e.message);
        }
      }
      return RpcResponse.primitive(signatures.map((e) => {
        "signature": {"type": null, "value": e.bytes},
        "publicKey": {
          "type": "PublicKey",
          "value": [_wallet!.publicKey.toBase58()]
        },
      }).toList());
    } else {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }
  }

  static RpcResponse? _sigPreChecks(ContextHolder contextHolder) {
    if (contextHolder.disposed) {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }
    if (!_connected) {
      return RpcResponse.error(RpcConstants.kUnauthorized);
    }
    return null;
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