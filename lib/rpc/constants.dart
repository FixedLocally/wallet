class RpcConstants {
  static const int kDisconnected = 4900;
  static const int kUnauthorized = 4100;
  static const int kUserRejected = 4001;

  static const int kInvalidInput = -32000;
  static const int kTransactionRejected = -32003;
  static const int kMethodNotFound = -32601;
  static const int kInternalError = -32603;

  static final Uri kRpcUrl = Uri.parse("https://api.mainnet-beta.solana.com");
  static final Uri kWsUrl = Uri.parse("wss://api.mainnet-beta.solana.com");

  static const Map<int, String> kErrorMessages = {
    kInvalidInput: "Invalid Input",
    kTransactionRejected: "Transaction Rejected",
    kMethodNotFound: "Method Not Found",
    kInternalError: "Internal Error",
    kDisconnected: "Disconnected",
    kUnauthorized: "Unauthorized",
    kUserRejected: "User Rejected Request",
  };
}