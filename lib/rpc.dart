class Rpc {
  static Future<RpcResponse> rpcEntryPoint(String method, Map args) async {
    print("rpcEntryPoint: $method, $args");
    return RpcResponse(false, 0);
  }
}

class RpcResponse {
  final bool isError;
  final dynamic response;

  RpcResponse(this.isError, this.response);
}