import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wallet/rpc/constants.dart';

import 'event.dart';
import 'response.dart';

String _hardcodedWallet = "EpDbR2jE1YB9Tutk36EtKrqz4wZBCwZNMdbHvbqd3TCv";
// String _hardcodedWallet = "GQP9XKoRfwo229MA8iDq8GsC4piAruxrg578QbTNQuqD";

class RpcServer {
  static final StreamController<RpcEvent> _eventStreamController = StreamController.broadcast();

  static Stream<RpcEvent> get eventStream => _eventStreamController.stream;

  static Future<RpcResponse> entryPoint(BuildContext context, String method, Map args) async {
    print("rpcEntryPoint: $method, $args");
    switch (method) {
      case "print":
        return _print(context, args);
      case "exit":
        return _exit(context, args);
      case "connect":
        return _connect(context, args);
      case "disconnect":
        return _disconnect(context, args);
    }
    return RpcResponse.error(RpcConstants.kMethodNotFound);
  }

  // print a message to the console
  static Future<RpcResponse> _print(BuildContext context, Map args) async {
    print("rpcCall: print: ${args["message"]}");
    return RpcResponse.primitive(0);
  }

  // show a "ask for permission" dialog
  static Future<RpcResponse> _exit(BuildContext context, Map args) async {
    RpcResponse? resp = await showModalBottomSheet<RpcResponse>(
      context: context,
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
                        Navigator.of(context).pop(RpcResponse.primitive("can exit"));
                      },
                      child: const Text("Yes"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(RpcResponse.error(RpcConstants.kUserRejected));
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
    return resp ?? RpcResponse.error(RpcConstants.kUserRejected);
  }

  // return a pubkey
  static Future<RpcResponse> _connect(BuildContext context, Map args) async {
    if (args["onlyIfTrusted"] == true) {
      return RpcResponse.error(RpcConstants.kUserRejected);
    }
    // await Future.delayed(const Duration(milliseconds: 2500));
    _eventStreamController.add(RpcEvent.object(
      "connect",
      "PublicKey", [_hardcodedWallet],
      {
        "publicKey": {"type": "PublicKey", "value": [_hardcodedWallet]},
        "isConnected": {"type": null, "value": true},
      },
    ));
    return RpcResponse.object("PublicKey", [_hardcodedWallet]);
  }

  // disconnect wallet
  static Future<RpcResponse> _disconnect(BuildContext context, Map args) async {
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
}
