extension TokenMint on String {
  String get shortened => "${substring(0, 5)}...${substring(length - 5)}";
}