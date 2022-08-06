import 'constants.dart';

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

  factory RpcResponse.error(int error) {
    return RpcResponse._(true, {"code": error, "error": RpcConstants.kErrorMessages[error]});
  }

  @override
  String toString() {
    return 'RpcResponse._(isError: $isError, response: $response)';
  }
}
