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

  @override
  String toString() {
    return 'YieldOpportunity{name: $name, apy: $apy, api: $api}';
  }
}