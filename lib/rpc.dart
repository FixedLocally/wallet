import 'dart:async';

import 'package:flutter/material.dart';

class Rpc {
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
    }
    return RpcResponse.error("Unknown method: $method");
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
                        Navigator.of(context).pop(RpcResponse.error("cannot exit"));
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
    return resp ?? RpcResponse.error("cannot exit");
  }

  // return a pubkey
  static Future<RpcResponse> _connect(BuildContext context, Map args) async {
    if (args["onlyIfTrusted"] == true) {
      return RpcResponse.error("cannot connect");
    }
    _eventStreamController.add(RpcEvent.object(
      "connect",
      "PublicKey", ["GQP9XKoRfwo229MA8iDq8GsC4piAruxrg578QbTNQuqD"],
      {
        "publicKey": {"type": "PublicKey", "value": ["GQP9XKoRfwo229MA8iDq8GsC4piAruxrg578QbTNQuqD"]},
      },
    ));
    return RpcResponse.object("PublicKey", ["GQP9XKoRfwo229MA8iDq8GsC4piAruxrg578QbTNQuqD"]);
  }
}

class RpcResponse {
  final bool isError;
  final Map response;

  RpcResponse._(this.isError, this.response);

  factory RpcResponse.primitive(dynamic response) {
    return RpcResponse._(false, {"type": null, "value": response});
  }

  factory RpcResponse.object(String type, List params) {
    return RpcResponse._(false, {"type": type, "value": params});
  }

  factory RpcResponse.error(dynamic error) {
    return RpcResponse._(true, {"type": null, "value": error});
  }

  @override
  String toString() {
    return 'RpcResponse._(isError: $isError, response: $response)';
  }
}

class RpcEvent {
  /// event type
  final String trigger;
  /// event params
  final Map response;
  /// vars to update in the injected scope
  final Map<String, Map> updates;

  RpcEvent._(this.trigger, this.response, [this.updates = const {}]);

  factory RpcEvent.primitive(String trigger, dynamic response, [Map<String, Map> updates = const {}]) {
    return RpcEvent._(trigger, {"type": null, "value": response}, updates);
  }

  factory RpcEvent.object(String trigger, String type, List params, [Map<String, Map> updates = const {}]) {
    return RpcEvent._(trigger, {"type": type, "value": params}, updates);
  }

  factory RpcEvent.error(String trigger, dynamic error, [Map<String, Map> updates = const {}]) {
    return RpcEvent._(trigger, {"type": null, "value": error}, updates);
  }

  @override
  String toString() {
    return 'RpcEvent._(trigger: $trigger, response: $response)';
  }
}