import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/metaplex.dart';
import 'package:solana/solana.dart';
import 'package:sqflite/sqflite.dart';

import '../rpc/constants.dart';
import '../rpc/key_manager.dart';

const String _coinGeckoUrl = "https://api.coingecko.com/api/v3/simple/token_price/solana?vs_currencies=usd&include_24hr_change=true&contract_addresses=";
const nativeSol = "native-sol";
const nativeSolMint = "So11111111111111111111111111111111111111112";
const Map<String, dynamic> _hardCodedPrices = {
  "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v": {
    "usd": 1.0,
    "usd_24h_change": 0.0,
  }, // usdc
};
class Utils {
  static final SolanaClient _solanaClient = SolanaClient(rpcUrl: RpcConstants.kRpcUrl, websocketUrl: RpcConstants.kWsUrl);

  static String _injectionJs = "";
  static Completer<void>? _completer;
  static Database? _db;

  static String get injectionJs => _injectionJs;

  static Future loadAssets() async {
    if (_injectionJs.isNotEmpty) return;
    if (_completer != null) return;
    _completer = Completer<void>();
    Future f1 = _openDatabase().then((value) => _db = value);
    Future f2 = rootBundle.loadString('assets/inject.js').then((String js) {
      _injectionJs = js;
    });

    Future f3 = KeyManager.instance.init();
    Future.wait([f1, f2, f3]).then((value) => _completer!.complete(null));
    return _completer!.future;
  }

  static Future<Map<String, dynamic>?> getToken(String token) async {
    return (await getTokens([token]))[token];
  }

  static Future<Map<String, Map<String, dynamic>?>> getTokens(List<String> tokens) async {
    Map<String, Map<String, dynamic>?> tokenInfos = await _db!.query("token", where: "mint IN (${tokens.map((token) => '?').join(',')})", whereArgs: tokens).then((List<Map<String, dynamic>> tokens) {
      Map<String, Map<String, dynamic>?> result = {};
      for (Map<String, dynamic> token in tokens) {
        result[token['mint']] = token;
      }
      return result;
    });
    List<String> remainingTokens = List.of(tokens)..removeWhere((element) => tokenInfos[element] != null);
    print('fetching $remainingTokens');
    List<int> metaplexSeed = base58decode(metaplexMetadataProgramId);
    List<Future<List<Object?>>> futures = remainingTokens.map((token) async {
      Ed25519HDPublicKey pda = await Ed25519HDPublicKey.findProgramAddress(seeds: ["metadata".codeUnits, metaplexSeed, base58decode(token)], programId: Ed25519HDPublicKey(metaplexSeed));
      Account? acct = await _solanaClient.rpcClient.getAccountInfo(pda.toBase58(), encoding: Encoding.base64);
      if (acct != null) {
        if (acct.data is BinaryAccountData) {
          Metadata metadata = Metadata.fromBinary((acct.data as BinaryAccountData).data);
          Map<String, dynamic> result = {
            "mint": token,
            "name": metadata.name,
            "symbol": metadata.symbol,
            // "standard": metadata.,
          };
          try {
            Mint mint = await _solanaClient.getMint(address: Ed25519HDPublicKey.fromBase58(token));
            result["decimals"] = mint.decimals;
            result["nft"] = mint.supply.toInt() == 1 && mint.decimals == 0;
          } catch (_) {}
          try {
            OffChainMetadata offChainMetadata = await metadata.getExternalJson();
            result["name"] = offChainMetadata.name;
            result["symbol"] = offChainMetadata.symbol;
            result["image"] = offChainMetadata.image;
          } catch (_) {}
          return [token, result];
        } else {
          return [token, null];
        }
      }
      return [token, null];
    }).toList();
    List<List> metadatas = await Future.wait(futures);
    if (metadatas.isNotEmpty) {
      await _db!.transaction((txn) async {
        for (List<Object?> metadata in metadatas) {
          if (metadata[1] != null) {
            Map<String, dynamic> metadataMap = metadata[1] as Map<String, dynamic>;
            tokenInfos[metadata[0] as String] = metadataMap;
            await txn.insert(
              "token",
              {
                "mint": metadataMap["mint"],
                "symbol": metadataMap["symbol"],
                "name": metadataMap["name"],
                "decimals": metadataMap["decimals"],
                "image": metadataMap["image"],
                "nft": metadataMap["nft"],
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });
    }
    return tokenInfos;
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
        .where((e) => e.programId.toBase58() == TokenProgram.programId || e.programId.toBase58() == AssociatedTokenAccountProgram.programId)
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
    return TokenChanges(changes, updatedAcctsMap, await getTokens(updatedAcctsMap.values.map((e) => e.mint).toList()), postSolBalance - preSolBalance);
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

  static Future<List<SplTokenAccountDataInfoWithUsd>> getBalances(String pubKey) async {
    List<SplTokenAccountDataInfo> rawResults = [];
    List<ProgramAccount> accounts = await _solanaClient.rpcClient.getTokenAccountsByOwner(
      pubKey,
      const TokenAccountsFilter.byProgramId(TokenProgram.programId),
      encoding: Encoding.jsonParsed,
      commitment: Commitment.confirmed,
    );
    for (final ProgramAccount value in accounts) {
      if (value.account.data is ParsedSplTokenProgramAccountData) {
        ParsedSplTokenProgramAccountData data = value.account.data as ParsedSplTokenProgramAccountData;
        if (data.parsed is TokenAccountData) {
          TokenAccountData tokenAccountData = data.parsed as TokenAccountData;
          rawResults.add(tokenAccountData.info);
        }
      }
    }
    int lamports = await _solanaClient.rpcClient.getBalance(pubKey, commitment: Commitment.confirmed);
    rawResults.add(SplTokenAccountDataInfo(
      tokenAmount: TokenAmount(
        amount: "$lamports",
        decimals: 9,
        uiAmountString: (lamports / lamportsPerSol).toStringAsFixed(9),
      ),
      state: "",
      isNative: false,
      mint: nativeSol,
      owner: pubKey,
    ));
    Set<String> mints = rawResults.map((e) => e.mint).toSet();
    mints.add(nativeSolMint);
    Map<String, dynamic> prices = await _getCoinGeckoPrices(mints.toList());
    List<SplTokenAccountDataInfoWithUsd> results = rawResults.map((e) {
      String uiAmountString = e.tokenAmount.uiAmountString ?? "0";
      double amount = double.parse(uiAmountString);
      double unitPrice = prices[e.mint]?["usd"] ?? -1;
      double dailyChangePercent = prices[e.mint]?["usd_24h_change"] ?? 0;
      if (e.mint == nativeSol) {
        unitPrice = prices[nativeSolMint]?["usd"] ?? -1;
        dailyChangePercent = prices[nativeSolMint]?["usd_24h_change"] ?? 0;
      }
      double usd = unitPrice >= 0 ? unitPrice * amount : -1;
      return SplTokenAccountDataInfoWithUsd(
        info: e,
        usd: usd,
        usdChange: usd * (1 - 1 / (1 + dailyChangePercent / 100)),
      );
    }).toList();
    results.sort((a, b) => b.usd.compareTo(a.usd));
    return results;
  }

  static Future<Database> _openDatabase() async {
    return openDatabase(
      "token.db",
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(
          "CREATE TABLE token ("
              "mint TEXT PRIMARY KEY,"
              "symbol TEXT,"
              "name TEXT,"
              "decimals INTEGER,"
              "image TEXT,"
              "nft INTEGER DEFAULT 0"
              ")");
        // load token list into db
        Map<String, Map<String, dynamic>> tokenList = {};
        await rootBundle.load("assets/tokens.json").then((ByteData byteData) {
          tokenList.addAll(jsonDecode(utf8.decode(byteData.buffer.asUint8List())).cast<String, Map<String, dynamic>>());
        });
        for (String key in tokenList.keys) {
          await db.insert(
            "token",
            {
              "mint": key,
              "symbol": tokenList[key]!["symbol"],
              "name": tokenList[key]!["name"],
              "decimals": tokenList[key]!["decimals"],
              "image": tokenList[key]!["image"],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      },
    );
  }

  static Future<Map<String, dynamic>> _getCoinGeckoPrices(List<String> tokens) async {
    if (tokens.isEmpty) return {};
    String url = "$_coinGeckoUrl${tokens.join(",")}";
    Map<String, dynamic> json = jsonDecode(await _httpGet(url));
    return Map.of(_hardCodedPrices)..addAll(json);
  }

  static Future<String> _httpGet(String url) async {
    HttpClient client = HttpClient();
    HttpClientRequest request = await client.getUrl(Uri.parse(url));
    HttpClientResponse response = await request.close();
    return await response.transform(utf8.decoder).join();
  }
}

class TokenChanges {
  final Map<String, double> changes;
  final Map<String, SplTokenAccountDataInfo> updatedAccounts;
  final Map<String, Map<String, dynamic>?> tokens;
  final int solOffset;
  final bool error;

  TokenChanges(this.changes, this.updatedAccounts, this.tokens, this.solOffset) : error = false;
  TokenChanges.error() : changes = {}, updatedAccounts = {}, tokens = {}, solOffset = 0, error = true;

  static TokenChanges merge(List<TokenChanges> tokenChanges) {
    Map<String, double> changes = {};
    Map<String, SplTokenAccountDataInfo> updatedAccounts = {};
    Map<String, Map<String, dynamic>> tokens = {};
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
      tokenChanges[i].tokens.forEach((key, value) {
        if (value == null) return;
        tokens[key] = value;
      });
      solOffset += tokenChanges[i].solOffset;
    }
    return TokenChanges(changes, updatedAccounts, tokens, solOffset);
  }

  @override
  String toString() {
    return 'TokenChanges{changes: $changes, updatedAccounts: $updatedAccounts, solOffset: $solOffset}';
  }
}

class SplTokenAccountDataInfoWithUsd extends SplTokenAccountDataInfo {
  final double usd;
  final double usdChange;

  SplTokenAccountDataInfoWithUsd({
    required SplTokenAccountDataInfo info,
    required this.usd,
    required this.usdChange,
  }) : super(
          mint: info.mint,
          state: info.state,
          isNative: info.isNative,
          tokenAmount: info.tokenAmount,
          owner: info.owner,
        );
}