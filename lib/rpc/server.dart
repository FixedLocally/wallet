import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:sprintf/sprintf.dart';

import '../generated/l10n.dart';
import '../utils/utils.dart';
import '../widgets/domain_info.dart';
import '../widgets/text.dart';
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
      case "signMessage":
        return _signMessage(contextHolder, args);
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

    Future<List<TokenChanges>> simulation = Utils.simulateTxs([payload], KeyManager.instance.pubKey);
    bool approved = await Utils.showConfirmBottomSheet(
      context: contextHolder.context!,
      confirmText: S.current.approve,
      cancelText: S.current.cancel,
      bodyBuilder: (context) {
        return ApproveTransactionWidget(simulation: simulation, domain: args["domain"], title: args["title"], logoUrls: args["logo"].cast<String>());
      },
    );
    // auto reject mocked requests
    if (KeyManager.instance.mockPubKey != null) {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }
    if (approved) {
      if (Utils.prefs.getBool(Constants.kKeyRequireAuth) ?? false) {
        approved = await KeyManager.instance.authenticateUser(contextHolder.context!);
      }
    }
    if (approved) {
      // String recentBlockhash = args["recentBlockhash"];
      late SignedTx signedTx;
      Signature signature = await KeyManager.instance.sign(payload);
      if (args["sigs"] != null) {
        List suppliedSigs = args["sigs"];
        List<Signature> sigs = suppliedSigs.map((e) {
          Ed25519HDPublicKey publicKey = Ed25519HDPublicKey.fromBase58(e["publicKey"]);
          return Signature((e["signature"] ?? []).cast<int>(), publicKey: publicKey);
        }).toList();
        int dummyIndex = sigs.indexWhere((element) => element.bytes.isEmpty);
        if (dummyIndex >= 0) {
          sigs[dummyIndex] = signature;
        } else {
          sigs.add(signature);
        }
        signedTx = SignedTx(
          signatures: sigs,
          messageBytes: ByteArray(payload),
        );
        print(signedTx.signatures);
      } else {
        signedTx = SignedTx(
          signatures: [signature],
          messageBytes: ByteArray(payload),
        );
      }
      print(signature.toBase58());
      print(signedTx.encode());
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

  static Future<RpcResponse> _signMessage(ContextHolder contextHolder, Map args) async {
    RpcResponse? error = _sigPreChecks(contextHolder);
    if (error != null) {
      return error;
    }
    if (args["message"] == null) {
      return RpcResponse.error(RpcConstants.kInvalidInput);
    }

    List<int> payload = args["message"].cast<int>();
    String msg = utf8.decode(payload);

    bool approved = await Utils.showConfirmBottomSheet(
      context: contextHolder.context!,
      confirmText: S.current.approve,
      cancelText: S.current.cancel,
      bodyBuilder: (context) {
        return Column(
          children: [
            if (args["domain"] != null && args["title"] != null && args["logo"] != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DomainInfoWidget(
                  domain: args["domain"],
                  title: args["title"],
                  logoUrls: args["logo"].cast<String>(),
                ),
              ),
            HighlightedText(
              text: sprintf(S.of(context).signMessageHeadline,
                  [KeyManager.instance.walletName]),
            ),
            Text(msg),
          ],
        );
      },
    );
    // auto reject mocked requests
    if (KeyManager.instance.mockPubKey != null) {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }
    if (approved) {
      if (Utils.prefs.getBool(Constants.kKeyRequireAuth) ?? false) {
        approved = await KeyManager.instance.authenticateUser(contextHolder.context!);
      }
    }
    if (approved) {
      Signature signature = await KeyManager.instance.sign(payload);

      print(signature.toBase58());
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
      confirmText: S.current.approve,
      cancelText: S.current.cancel,
      bodyBuilder: (context) {
        return ApproveTransactionWidget(simulation: simulation, domain: args["domain"], title: args["title"], logoUrls: args["logo"].cast<String>());
      },
      doubleConfirm: payloads.length > 10 ? "I acknowledge the risk of approving these transactions." : null,
    );
    // auto reject mocked requests
    if (KeyManager.instance.mockPubKey != null) {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }
    if (approved) {
      if (Utils.prefs.getBool(Constants.kKeyRequireAuth) ?? false) {
        approved = await KeyManager.instance.authenticateUser(contextHolder.context!);
      }
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
