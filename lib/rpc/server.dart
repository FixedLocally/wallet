import 'dart:async';

import 'package:flutter/material.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../utils/utils.dart';
import 'event.dart';
import 'key_manager.dart';
import 'response.dart';
import '../routes/mixins/context_holder.dart';
import 'constants.dart';
import '../widgets/approve_tx.dart';

class RpcServer {
  static final StreamController<RpcEvent> _eventStreamController = StreamController.broadcast();

  static bool _init = false;
  static bool _connected = false;
  // static Wallet? _wallet;

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
      approved = await Utils.showConfirmBottomSheet(
        context: contextHolder.context!,
        bodyBuilder: (ctx) {
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
    if (contextHolder.context == null || !await KeyManager.instance.requestConnect(contextHolder.context!, args["domain"], args["title"], args["logo"].cast<String>(), args["onlyIfTrusted"] == true)) {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }

    // await Future.delayed(const Duration(milliseconds: 2500));
    _connected = true;
    _eventStreamController.add(RpcEvent.object(
      "connect",
      "PublicKey", [KeyManager.instance.pubKey],
      {
        "publicKey": {"type": "PublicKey", "value": [KeyManager.instance.pubKey]},
        "isConnected": {"type": null, "value": true},
      },
    ));
    return RpcResponse.primitive({
      "publicKey": {"type": "PublicKey", "value": [KeyManager.instance.pubKey]},
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

    Future<List<TokenChanges>> simulation = Utils.simulateTxs([payload], KeyManager.instance.pubKey);
    bool approved = await Utils.showConfirmBottomSheet(
      context: contextHolder.context!,
      bodyBuilder: (context) {
        return ApproveTransactionWidget(simulation: simulation, domain: args["domain"], title: args["title"], logoUrls: args["logo"].cast<String>());
      },
    );
    // auto reject mocked requests
    if (KeyManager.instance.mockPubKey != null) {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }
    if (approved) {
      String recentBlockhash = args["recentBlockhash"];
      SignedTx signedTx = await KeyManager.instance.signMessage(message, recentBlockhash);
      print(signedTx.signatures.first.toBase58());
      Signature signature = await KeyManager.instance.sign(payload);
      print(signedTx.encode());
      print(signature.toBase58());
      if (send) {
        try {
          String sig = await Utils.sendTransaction(signedTx);
          return RpcResponse.primitive({
            "signature": {"type": null, "value": sig},
            "publicKey": {
              "type": "PublicKey",
              "value": [KeyManager.instance.pubKey]
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
          "value": [KeyManager.instance.pubKey]
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
    for (var e in txs) {
      List<int> payload = e["tx"].cast<int>();
      CompiledMessage compiledMessage = CompiledMessage(ByteArray(payload));
      Message message = Message.decompile(compiledMessage);
      compiledMessages.add(compiledMessage);
      messages.add(message);
      payloads.add(payload);
      blockhashes.add(e["recentBlockhash"]);
    }

    Future<List<TokenChanges>> simulation = Utils.simulateTxs(payloads, KeyManager.instance.pubKey);
    bool approved = await Utils.showConfirmBottomSheet(
      context: contextHolder.context!,
      bodyBuilder: (context) {
        return ApproveTransactionWidget(simulation: simulation, domain: args["domain"], title: args["title"], logoUrls: args["logo"].cast<String>());
      },
    );
    // auto reject mocked requests
    if (KeyManager.instance.mockPubKey != null) {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }
    if (approved) {
      List<SignedTx> signedTxs = [];
      List<Signature> signatures = [];
      for (int i = 0; i < payloads.length; ++i) {
        String recentBlockhash = blockhashes[i];
        SignedTx signedTx = await KeyManager.instance.signMessage(messages[i], recentBlockhash);
        Signature signature = await KeyManager.instance.sign(payloads[i]);
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
            String sig = await Utils.sendTransaction(signedTx);
            sigs.add(sig);
          }
          return RpcResponse.primitive(sigs.map((e) => {
            "signature": {"type": null, "value": e},
            "publicKey": {
              "type": "PublicKey",
              "value": [KeyManager.instance.pubKey]
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
          "value": [KeyManager.instance.pubKey]
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
