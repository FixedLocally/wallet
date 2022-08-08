import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../rpc/constants.dart';
import '../rpc/key_manager.dart';

class Utils {
  static final SolanaClient _solanaClient = SolanaClient(rpcUrl: RpcConstants.kRpcUrl, websocketUrl: RpcConstants.kWsUrl);

  static final Map<String, Map<String, dynamic>> _tokenList = {};
  static String _injectionJs = "";
  static Completer<void>? _completer;

  static String get injectionJs => _injectionJs;

  static Future loadAssets() async {
    if (_tokenList.isNotEmpty && _injectionJs.isNotEmpty) return;
    if (_completer != null) return;
    _completer = Completer<void>();
    Future f1 = rootBundle.load("assets/tokens.json").then((ByteData byteData) {
      _tokenList.addAll(jsonDecode(utf8.decode(byteData.buffer.asUint8List())).cast<String, Map<String, dynamic>>());
    });
    Future f2 = rootBundle.loadString('assets/inject.js').then((String js) {
      _injectionJs = js;
    });
    Future f3 = KeyManager.instance.init();
    Future.wait([f1, f2, f3]).then((value) => _completer!.complete(null));
    return _completer!.future;
  }

  static Map<String, dynamic>? getToken(String token) {
    return _tokenList[token];
  }

  static Future<SplTokenAccountDataInfo> parseTokenAccount(List<int> data) async {
    List<int> rawMint = data.sublist(0, 32);
    String mint = base58encode(rawMint);
    List<int> rawOwner = data.sublist(32, 64);
    String owner = base58encode(rawOwner);
    List<int> rawAmount = data.sublist(64, 72);
    int amount = Int8List.fromList(rawAmount).buffer.asUint64List().first;
    List<int> rawDelegate = data.sublist(72, 108);
    String? delegate = rawDelegate.sublist(0, 4).any((e) => e != 0) ? null : base58encode(rawDelegate.sublist(4));
    List<int> rawState = data.sublist(108, 109);
    List<int> rawIsNative = data.sublist(109, 121);
    bool isNative = rawIsNative.sublist(0, 4).any((e) => e != 0);
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
      state: "${rawState[0]}",
      isNative: isNative,
      // delegatedAmount: delegatedAmount,
      // closeAuthority: closeAuthority,
    );
  }

  // get accounts in batches of 10
  static Future<List<Account?>> batchGetAccounts(List<String> addresses) async{
    List<Account?> accounts = [];
    for (int i = 0; i < addresses.length; i += 10) {
      List<String> batch = addresses.sublist(i, min(i + 10, addresses.length));
      accounts.addAll(await _solanaClient.rpcClient.getMultipleAccounts(batch, commitment: Commitment.confirmed, encoding: Encoding.base64));
    }
    return accounts;
  }

  static Future<TokenChanges> simulateTx(List<int> rawMessage, String owner) async {
    CompiledMessage compiledMessage = CompiledMessage(ByteArray(rawMessage));
    Message message = Message.decompile(compiledMessage);
    // prepend header
    List<int> simulationPayload = [1, ...List.generate(64, (_) => 0), ...rawMessage];
    List<String> addresses = message.instructions
        .map((e) => e.accounts.map((e) => e.pubKey.toBase58()).toList()).toList()
        .expand((e) => e).toSet().toList();
    List<String> tokenProgramAddresses = message.instructions
        .where((e) => e.programId.toBase58() == "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA" || e.programId.toBase58() == "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL")
        .map((e) => e.accounts.map((e) => e.pubKey.toBase58()).toList()).toList()
        .expand((e) => e).where((e) => !e.contains("111111111")).toSet().toList();
    List<Account?> accounts = await batchGetAccounts(addresses);
    for (int i = 0; i < addresses.length; i++) {
      if (accounts[i] != null) {
        if ((accounts[i]!.data as BinaryAccountData).data.length != 165) {
          addresses[i] = "";
        }
      } else {
        if (!tokenProgramAddresses.contains(addresses[i])) {
          addresses[i] = "";
        }
      }
    }
    addresses = addresses.where((element) => element.isNotEmpty).toList();
    addresses = [...addresses, owner];
    Future<TransactionStatus> statusFuture = _solanaClient.rpcClient.simulateTransaction(
      base64Encode(simulationPayload),
      replaceRecentBlockhash: true,
      commitment: Commitment.confirmed,
      accounts: SimulateTransactionAccounts(
        accountEncoding: Encoding.jsonParsed,
        addresses: addresses,
      ),
    );
    Future<int> solBalanceFuture = _solanaClient.rpcClient.getBalance(owner, commitment: Commitment.confirmed);
    List results = await Future.wait([statusFuture, solBalanceFuture]).catchError((_) => <Object>[]);
    if (results.isEmpty) return TokenChanges.error();
    TransactionStatus status = results[0];
    int preSolBalance = results[1];

    List<String> tokenAccounts = [];
    List<Future<SplTokenAccountDataInfo>> updatedAcctFutures = [];
    List<Future<TokenAmount?>> preBalanceFutures = [];
    int count = 0;
    for (int i = 0; i < addresses.length - 1; ++i) {
      Account? element = status.accounts?[i];
      if (element?.data is BinaryAccountData) {
        List<int> data = (element?.data as BinaryAccountData).data;
        if (data.length == RpcConstants.kTokenAccountLength) {
          tokenAccounts.add(addresses[i]);
          updatedAcctFutures.add(Utils.parseTokenAccount(data));
          preBalanceFutures.add(_getTokenAmountOrNull(addresses[i]));
          ++count;
        }
      }
    }
    int postSolBalance = status.accounts?.last.lamports ?? 0;
    List result = await Future.wait([Future.wait(updatedAcctFutures), Future.wait(preBalanceFutures)]);
    List<SplTokenAccountDataInfo> updatedAccts = result[0];
    List<TokenAmount?> preBalances = result[1];
    Map<String, SplTokenAccountDataInfo> updatedAcctsMap = {};
    Map<String, double> changes = {};
    for (int i = 0; i < count; ++i) {
      double oldAmt = double.parse(preBalances[i]?.uiAmountString ?? "0");
      double newAmt = double.parse(updatedAccts[i].tokenAmount.uiAmountString!);
      if (updatedAccts[i].owner == owner) {
        changes[tokenAccounts[i]] = newAmt - oldAmt;
        updatedAcctsMap[tokenAccounts[i]] = updatedAccts[i];
      }
    }
    return TokenChanges(changes, updatedAcctsMap, postSolBalance - preSolBalance);
  }

  static Future<TokenChanges> simulateTxs(List<List<int>> rawMessage, String owner) async {
    List<TokenChanges> changes = [];
    for (int i = 0; i < rawMessage.length; ++i) {
      changes.add(await simulateTx(rawMessage[i], owner));
    }
    TokenChanges mergedChanges = TokenChanges.merge(changes);
    return mergedChanges;
  }

  static Future<TokenAmount?> _getTokenAmountOrNull(String address) async {
    try {
      return await _solanaClient.rpcClient.getTokenAccountBalance(address, commitment: Commitment.confirmed);
    } catch (e) {
      return null;
    }
  }

  static Future<T> showLoadingDialog<T>(BuildContext context, Future<T> future) async {
    showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text("Loading..."),
            ],
          ),
        );
      },
    );
    return future.whenComplete(() {
      Navigator.of(context).pop();
    });
  }
}

class TokenChanges {
  final Map<String, double> changes;
  final Map<String, SplTokenAccountDataInfo> updatedAccounts;
  final int solOffset;
  final bool error;

  TokenChanges(this.changes, this.updatedAccounts, this.solOffset) : error = false;
  TokenChanges.error() : changes = {}, updatedAccounts = {}, solOffset = 0, error = true;

  static TokenChanges merge(List<TokenChanges> tokenChanges) {
    Map<String, double> changes = {};
    Map<String, SplTokenAccountDataInfo> updatedAccounts = {};
    int solOffset = 0;
    for (int i = 0; i < tokenChanges.length; ++i) {
      if (tokenChanges[i].error) {
        return TokenChanges.error();
      }
      tokenChanges[i].changes.forEach((key, value) {
        changes[key] = (changes[key] ?? 0) + value;
      });
      tokenChanges[i].updatedAccounts.forEach((key, value) {
        updatedAccounts[key] = value;
      });
      solOffset += tokenChanges[i].solOffset;
    }
    return TokenChanges(changes, updatedAccounts, solOffset);
  }

  @override
  String toString() {
    return 'TokenChanges{changes: $changes, updatedAccounts: $updatedAccounts, solOffset: $solOffset}';
  }
}