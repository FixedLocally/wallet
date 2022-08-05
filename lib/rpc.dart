import 'package:flutter/material.dart';

class Rpc {
  static Future<RpcResponse> entryPoint(BuildContext context, String method, Map args) async {
    print("rpcEntryPoint: $method, $args");
    switch (method) {
      case "print":
        return _print(context, args);
      case "exit":
        return _exit(context, args);
    }
    return RpcResponse(true, "Unknown method: $method");
  }

  static Future<RpcResponse> _print(BuildContext context, Map args) async {
    print("rpcCall: print: ${args["message"]}");
    return RpcResponse(false, 0);
  }

  static Future<RpcResponse> _exit(BuildContext context, Map args) async {
    print("rpcCall: exit: $args");
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
                        Navigator.of(context).pop(RpcResponse(false, "can exit"));
                      },
                      child: const Text("Yes"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(RpcResponse(true, "cannot exit"));
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
    return resp ?? RpcResponse(true, "cannot exit");
  }
}

class RpcResponse {
  final bool isError;
  final dynamic response;

  RpcResponse(this.isError, this.response);
}