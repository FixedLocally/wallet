import 'dart:convert';

import '../utils/utils.dart';

class YieldOpportunity {
  final String name;
  final double apy;
  final String api;

  YieldOpportunity({
    required this.name,
    required this.apy,
    required this.api,
  });

  factory YieldOpportunity.fromJson(Map<String, dynamic> json) {
    return YieldOpportunity(
      name: json['name'],
      apy: json['apy'],
      api: json['api'],
    );
  }

  Future<List<List<int>>> getTxs(String pubkey, int amount) async {
    String response = await Utils.httpGet("https://validator.utopiamint.xyz$api".replaceAll("{pubkey}", pubkey).replaceAll("{amount}", amount.toString()));
    Map json = jsonDecode(response);
    List<List<int>> txs = [];
    for (String key in ["preTx", "lendingTx", "postTx"]) {
      if (json["txs"][key] != null) {
        txs.add(base64Decode(json["txs"][key]));
      }
    }
    return txs;
  }

  @override
  String toString() {
    return 'YieldOpportunity{name: $name, apy: $apy, api: $api}';
  }
}