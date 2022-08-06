import 'dart:async';

import 'package:flutter/material.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:wallet/context_holder.dart';
import 'package:wallet/rpc/constants.dart';

import 'event.dart';
import 'response.dart';

String _hardcodedWallet = "EpDbR2jE1YB9Tutk36EtKrqz4wZBCwZNMdbHvbqd3TCv";
// String _hardcodedWallet = "GQP9XKoRfwo229MA8iDq8GsC4piAruxrg578QbTNQuqD";

class RpcServer {
  static final StreamController<RpcEvent> _eventStreamController = StreamController.broadcast();

  static bool _init = false;
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
        return _signTransaction(contextHolder, args);
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
    RpcResponse? resp;
    if (contextHolder.context != null) {
      resp = await showModalBottomSheet<RpcResponse>(
        context: contextHolder.context!,
        builder: (ctx) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Column(
                children: [
                  const Text("Exit?"),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(contextHolder.context!).pop(
                              RpcResponse.primitive("can exit"));
                        },
                        child: const Text("Yes"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(contextHolder.context!).pop(
                              RpcResponse.error(RpcConstants.kUserRejected));
                        },
                        child: const Text("No"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    return resp ?? RpcResponse.error(RpcConstants.kUserRejected);
  }

  // return a pubkey
  static Future<RpcResponse> _connect(ContextHolder contextHolder, Map args) async {
    if (args["onlyIfTrusted"] == true) {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }

    // await Future.delayed(const Duration(milliseconds: 2500));
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
  static Future<RpcResponse> _signTransaction(ContextHolder contextHolder, Map args) async {
    List<int> payload = args["tx"].cast<int>();
    Message message = Message.decompile(CompiledMessage(ByteArray(payload)));
    String recentBlockhash = args["recentBlockhash"];
    SignedTx signedTx = await _wallet!.signMessage(message: message, recentBlockhash: recentBlockhash);
    return RpcResponse.primitive({
      "signature": {"type": null, "value": signedTx.signatures.first.bytes},
      "publicKey": {"type": "PublicKey", "value": [_wallet!.publicKey.toBase58()]},
    });
  }
}
