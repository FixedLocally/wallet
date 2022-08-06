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