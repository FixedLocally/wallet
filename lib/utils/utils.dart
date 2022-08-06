import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../rpc/constants.dart';

class Utils {
  static final SolanaClient _solanaClient = SolanaClient(rpcUrl: RpcConstants.kRpcUrl, websocketUrl: RpcConstants.kWsUrl);
  static final Map<String, Map<String, dynamic>> _tokenList = {};

  static Future loadTokenList() async {
    if (_tokenList.isNotEmpty) return _tokenList;
    rootBundle.load("assets/tokens.json").then((ByteData byteData) {
      _tokenList.addAll(jsonDecode(utf8.decode(byteData.buffer.asUint8List())).cast<String, Map<String, dynamic>>());
    });
  }

  static Map<String, dynamic>? getToken(String token) {
    return _tokenList[token];
  }

  static Future<SplTokenAccountDataInfo> parseTokenAccount(List<int> data) async {
    List<int> _mint = data.sublist(0, 32);
    String mint = base58encode(_mint);
    List<int> _owner = data.sublist(32, 64);
    String owner = base58encode(_owner);
    List<int> _amount = data.sublist(64, 72);
    int amount = Int8List.fromList(_amount).buffer.asUint64List().first;
    List<int> _delegate = data.sublist(72, 108);
    String? delegate = _delegate.sublist(0, 4).any((e) => e != 0) ? null : base58encode(_delegate.sublist(4));
    List<int> _state = data.sublist(108, 109);
    List<int> _isNative = data.sublist(109, 121);
    bool isNative = _isNative.sublist(0, 4).any((e) => e != 0);
    // List<int> _delegatedAmount = data.sublist(121, 129);
    // int? delegatedAmount = _delegatedAmount.sublist(0, 4).any((e) => e != 0) ? null : Int8List.fromList(_delegatedAmount).buffer.asUint64List().first;
    // List<int> _closeAuthority = data.sublist(129, 165);
    // String? closeAuthority = _closeAuthority.sublist(0, 4).any((e) => e != 0) ? null : base58encode(_closeAuthority.sublist(4));
    Account? mintAcct = await _solanaClient.rpcClient.getAccountInfo(
      mint,
      commitment: Commitment.confirmed,
      encoding: Encoding.base64,
    );
    // https://github.com/solana-labs/solana-program-library/blob/48fbb5b7/token/js/src/state/mint.ts#L43
    int decimals = (mintAcct?.data as BinaryAccountData).data[4 + 32 + 8];
    return SplTokenAccountDataInfo(
      mint: mint,
      owner: owner,
      tokenAmount: TokenAmount(amount: "$amount", decimals: decimals, uiAmountString: "${amount / pow(10, decimals)}"),
      delegate: delegate,
      state: "${_state[0]}",
      isNative: isNative,
      // delegatedAmount: delegatedAmount,
      // closeAuthority: closeAuthority,
    );
  }

  static Future<TokenChanges> simulateTx(List<int> rawMessage, String owner) async {
    CompiledMessage compiledMessage = CompiledMessage(ByteArray(rawMessage));
    Message message = Message.decompile(compiledMessage);
    // prepend header
    List<int> simulationPayload = [1, ...List.generate(64, (_) => 0), ...rawMessage];
    List<String> addresses = message.instructions
        .map((e) => e.accounts.map((e) => e.pubKey.toBase58()).toList()).toList()
        .expand((e) => e).toList();
    TransactionStatus status = await _solanaClient.rpcClient.simulateTransaction(
      base64Encode(simulationPayload),
      replaceRecentBlockhash: true,
      commitment: Commitment.confirmed,
      accounts: SimulateTransactionAccounts(
        accountEncoding: Encoding.jsonParsed,
        addresses: addresses,
      ),
    );

    List<String> tokenAccounts = [];
    List<Future<SplTokenAccountDataInfo>> updatedAcctFutures = [];
    List<Future<TokenAmount>> preBalanceFutures = [];
    int count = 0;
    for (int i = 0; i < addresses.length; ++i) {
      Account? element = status.accounts?[i];
      if (element?.data is BinaryAccountData) {
        List<int> data = (element?.data as BinaryAccountData).data;
        if (data.length == RpcConstants.kTokenAccountLength) {
          tokenAccounts.add(addresses[i]);
          updatedAcctFutures.add(Utils.parseTokenAccount(data));
          preBalanceFutures.add(_solanaClient.rpcClient.getTokenAccountBalance(addresses[i], commitment: Commitment.confirmed));
          ++count;
        }
      }
    }
    List result = await Future.wait([Future.wait(updatedAcctFutures), Future.wait(preBalanceFutures)]);
    List<SplTokenAccountDataInfo> updatedAccts = result[0];
    List<TokenAmount> preBalances = result[1];
    Map<String, SplTokenAccountDataInfo> updatedAcctsMap = {};
    Map<String, double> changes = {};
    for (int i = 0; i < count; ++i) {
      double oldAmt = double.parse(preBalances[i].uiAmountString!);
      double newAmt = double.parse(updatedAccts[i].tokenAmount.uiAmountString!);
      print("${tokenAccounts[i]} ${updatedAccts[i].owner} ${updatedAccts[i].mint} $oldAmt -> $newAmt");
      if (updatedAccts[i].owner == owner) {
        changes[tokenAccounts[i]] = newAmt - oldAmt;
        updatedAcctsMap[tokenAccounts[i]] = updatedAccts[i];
      }
    }
    return TokenChanges(message, changes, updatedAcctsMap);
  }
}

class TokenChanges {
  final Message message;
  final Map<String, double> changes;
  final Map<String, SplTokenAccountDataInfo> updatedAccounts;

  TokenChanges(this.message, this.changes, this.updatedAccounts);
}