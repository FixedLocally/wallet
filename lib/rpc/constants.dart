class RpcConstants {
  static const int kDisconnected = 4900;
  static const int kUnauthorized = 4100;
  static const int kUserRejected = 4001;

  static const int kInvalidInput = -32000;
  static const int kTransactionRejected = -32003;
  static const int kMethodNotFound = -32601;
  static const int kInternalError = -32603;

  static const int kTokenAccountLength = 165;

  static final Uri kRpcUrl = Uri.parse("https://api.mainnet-beta.solana.com");
  static final Uri kWsUrl = Uri.parse("wss://api.mainnet-beta.solana.com");
  // static final Uri kWsUrl = Uri.parse("wss://ssc-dao.genesysgo.net");
  // static final Uri kRpcUrl = Uri.parse("https://ssc-dao.genesysgo.net");

  static const Map<int, String> kErrorMessages = {
    kInvalidInput: "Invalid Input",
    kTransactionRejected: "Transaction Rejected",
    kMethodNotFound: "Method Not Found",
    kInternalError: "Internal Error",
    kDisconnected: "Disconnected",
    kUnauthorized: "The requested method and/or account has not been authorized by the user.",
    kUserRejected: "User rejected the request",
  };
}

class Constants {
  static const String kKeySwapFrom = "swap_from";
  static const String kKeySwapTo = "swap_to";
}