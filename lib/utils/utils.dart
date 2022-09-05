import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart' hide Instruction;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:sprintf/sprintf.dart';
import 'package:sqflite/sqflite.dart';

import '../generated/l10n.dart';
import '../rpc/constants.dart';
import '../rpc/key_manager.dart';

const String _coinGeckoUrl = "https://api.coingecko.com/api/v3/simple/token_price/solana?vs_currencies=usd&include_24hr_change=true&contract_addresses=";
const String _topTokensUrl = "https://cache.jup.ag/top-tokens";
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
    int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    Map<String, Map<String, dynamic>?> tokenInfos = await _db!.query("token", where: "mint IN (${tokens.map((token) => '?').join(',')}) and (expiry>? or expiry is null)", whereArgs: [...tokens, now]).then((List<Map<String, dynamic>> tokens) async {
      Map<String, Map<String, dynamic>?> result = {};
      for (Map<String, dynamic> token in tokens) {
        token = Map.of(token);
        result[token['mint']] = token;
      }
      return result;
    });
    List<String> remainingTokens = List.of(tokens)..removeWhere((element) => tokenInfos[element] != null);
    debugPrint('fetching $remainingTokens');
    // int i = 0;
    // List<Future<List<Object?>>> futures = remainingTokens.map((token) async {
    //   // artificial delay to avoid hitting the rate limit
    //   await Future.delayed(Duration(milliseconds: i++ * 100));
    //   Map resp = jsonDecode(await _httpGet("https://validator.utopiamint.xyz/token-api/token/$token"));
    //   return [token, resp["success"] ? resp["token"] : null];
    // }).toList();
    // List<List> metadatas = await Future.wait(futures);
    List<List> metadatas = await batchGetMetadata(remainingTokens);
    debugPrint("got metadatas ${metadatas.length}");
    if (metadatas.isNotEmpty) {
      await _db!.transaction((txn) async {
        int inserted = 0;
        for (List<Object?> metadata in metadatas) {
          if (metadata[1] != null) {
            Map<String, dynamic> metadataMap = metadata[1] as Map<String, dynamic>;
            tokenInfos[metadata[0] as String] = metadataMap;
            debugPrint('inserting ${metadataMap['address']} $metadataMap');
            int id = await txn.insert(
              "token",
              {
                "mint": metadataMap["address"],
                "symbol": metadataMap["symbol"],
                "name": metadataMap["name"],
                "decimals": metadataMap["decimals"],
                "image": metadataMap["image"],
                "nft": metadataMap["nft"],
                "ext_url": metadataMap["ext_url"],
                "attributes": jsonEncode(metadataMap["attributes"]),
                "description": metadataMap["description"],
                "expiry": DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60 * 60 * 24 * 2,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            if (id > 0) {
              ++inserted;
            }
          }
        }
        debugPrint("inserted $inserted rows");
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
  static Future<List<Account?>> batchGetAccounts(List<String> addresses) async {
    List<Account?> accounts = [];
    for (int i = 0; i < addresses.length; i += 50) {
      List<String> batch = addresses.sublist(i, min(i + 50, addresses.length));
      accounts.addAll(await _solanaClient.rpcClient.getMultipleAccounts(batch, commitment: Commitment.confirmed, encoding: Encoding.base64));
    }
    return accounts;
  }

  static Future<TokenChanges> simulateTx(List<int> rawMessage, String owner) async {
    CompiledMessage compiledMessage = CompiledMessage(ByteArray(rawMessage));
    Message message = Message.decompile(compiledMessage);
    // prepend header
    List<int> simulationPayload = [1, ...List.generate(64, (_) => 0), ...rawMessage];
    // all addresses involved in the transaction
    List<String> addresses = message.instructions
        .map((e) => e.accounts.map((e) => e.pubKey.toBase58()).toList()).toList()
        .expand((e) => e).toSet().toList();
    // all accounts involved in the transaction while interacting with token programs (must get)
    List<String> tokenProgramAddresses = message.instructions
        .where((e) => e.programId.toBase58() == TokenProgram.programId || e.programId.toBase58() == AssociatedTokenAccountProgram.programId)
        .map((e) => e.accounts.map((e) => e.pubKey.toBase58()).toList()).toList()
    // normal token accts are unlikely to have that many 1s, probably system accts
        .expand((e) => e).where((e) => !e.contains("111111111")).toSet().toList();
    List<Account?> accounts = await batchGetAccounts(addresses);
    Map<String, Account?> accountMap = {};
    for (int i = 0; i < addresses.length; ++i) {
      accountMap[addresses[i]] = accounts[i];
    }
    // remove accounts that are not token accts and not null
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
        accountEncoding: Encoding.base64,
        addresses: addresses,
      ),
    );
    Future<int> solBalanceFuture = _solanaClient.rpcClient.getBalance(owner, commitment: Commitment.confirmed);
    List results = await Future.wait([statusFuture, solBalanceFuture]).catchError((_) => <Object>[]);
    if (results.isEmpty) return TokenChanges.error("cannot get results");
    TransactionStatus status = results[0];
    int preSolBalance = results[1];

    List<String> tokenAccounts = [];
    List<Future<SplTokenAccountDataInfo>> updatedAcctFutures = [];
    List<Future<SplTokenAccountDataInfo?>> preBalanceFutures = [];
    int count = 0;
    for (int i = 0; i < addresses.length - 1; ++i) {
      Account? element = status.accounts?[i];
      if (element?.data is BinaryAccountData) {
        List<int> data = (element?.data as BinaryAccountData).data;
        if (data.length == RpcConstants.kTokenAccountLength) {
          tokenAccounts.add(addresses[i]);
          updatedAcctFutures.add(Utils.parseTokenAccount(data));
          if (accountMap[addresses[i]] != null) {
            preBalanceFutures.add(Utils.parseTokenAccount((accountMap[addresses[i]]!.data as BinaryAccountData).data));
          } else {
            preBalanceFutures.add(Future.value(null));
          }
          ++count;
        }
      }
    }
    int postSolBalance = status.accounts?.last.lamports ?? 0;
    List result = await Future.wait([Future.wait(updatedAcctFutures), Future.wait(preBalanceFutures)]);
    List<SplTokenAccountDataInfo> updatedAccts = result[0];
    List<SplTokenAccountDataInfo?> preBalances = result[1];
    Map<String, SplTokenAccountDataInfo> updatedAcctsMap = {};
    Map<String, double> changes = {};
    for (int i = 0; i < count; ++i) {
      double oldAmt = double.parse(preBalances[i]?.tokenAmount.uiAmountString ?? "0");
      double newAmt = double.parse(updatedAccts[i].tokenAmount.uiAmountString!);
      if (preBalances[i]?.owner == owner) {
        if (updatedAccts[i].owner == preBalances[i]?.owner) {
          changes[tokenAccounts[i]] = newAmt - oldAmt;
        } else {
          // setAuthority'd - new balance is 0
          changes[tokenAccounts[i]] = -oldAmt;
        }
        updatedAcctsMap[tokenAccounts[i]] = updatedAccts[i];
      }
    }
    return TokenChanges(changes, updatedAcctsMap, await getTokens(updatedAcctsMap.values.map((e) => e.mint).toList()), postSolBalance - preSolBalance);
  }

  static Future<List<TokenChanges>> simulateTxs(List<List<int>> rawMessage, String owner) async {
    List<TokenChanges> changes = [];
    for (int i = 0; i < rawMessage.length; ++i) {
      // sequentially
      changes.add(await simulateTx(rawMessage[i], owner));
    }
    return changes;
  }

  static Future<RecentBlockhash> getBlockhash() async {
    return await _solanaClient.rpcClient.getRecentBlockhash(commitment: Commitment.confirmed);
  }

  static Future<String> sendTransaction(SignedTx tx, {Commitment preflightCommitment = Commitment.confirmed}) async {
    return _solanaClient.rpcClient.sendTransaction(
      tx.encode(),
      preflightCommitment: preflightCommitment,
    );
  }

  static Future<String> sendInstructions(List<Instruction> ixs , {Commitment preflightCommitment = Commitment.confirmed}) async {
    Message msg = Message(instructions: ixs);
    RecentBlockhash blockhash = await Utils.getBlockhash();
    SignedTx tx = await KeyManager.instance.signMessage(msg, blockhash.blockhash);
    String sig = await Utils.sendTransaction(tx);
    await Utils.confirmTransaction(sig);
    return sig;
  }

  static Future<Account?> getAccount(String pubkey) {
    return _solanaClient.rpcClient.getAccountInfo(pubkey, commitment: Commitment.confirmed, encoding: Encoding.base64);
  }

  static Future<void> confirmTransaction(
    String sig, {
    Commitment status = Commitment.confirmed,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return _solanaClient.waitForSignatureStatus(sig, status: status, timeout: timeout);
  }

  static Future<Map<String, dynamic>> _getCoinGeckoPrices(List<String> tokens) async {
    if (tokens.isEmpty) return {};
    String url = "$_coinGeckoUrl${tokens.join(",")}";
    Map<String, dynamic> json = jsonDecode(await _httpGet(url));
    return Map.of(_hardCodedPrices)..addAll(json);
  }

  static Future<List<SplTokenAccountDataInfoWithUsd>> getBalances(String pubKey) async {
    List<SplTokenAccountDataInfoWithUsd> rawResults = [];
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
          rawResults.add(SplTokenAccountDataInfoWithUsd(
            info: tokenAccountData.info,
            usd: null,
            usdChange: 0,
            account: value.pubkey,
          ));
        }
      }
    }
    int lamports = await _solanaClient.rpcClient.getBalance(pubKey, commitment: Commitment.confirmed);
    rawResults.add(SplTokenAccountDataInfoWithUsd(
      info: SplTokenAccountDataInfo(
        tokenAmount: TokenAmount(
          amount: "$lamports",
          decimals: 9,
          uiAmountString: (lamports / lamportsPerSol).toStringAsFixed(9),
        ),
        state: "",
        isNative: false,
        mint: nativeSol,
        owner: pubKey,
      ),
      usd: null,
      usdChange: 0,
      account: pubKey,
    ));
    Set<String> mints = rawResults.map((e) => e.mint).toSet();
    mints.add(nativeSolMint);
    Map<String, dynamic> prices = await _getCoinGeckoPrices(mints.toList());
    List<SplTokenAccountDataInfoWithUsd> results = rawResults.map((e) {
      String uiAmountString = e.tokenAmount.uiAmountString ?? "0";
      double amount = double.parse(uiAmountString);
      num unitPrice = prices[e.mint]?["usd"] ?? -1.0;
      num dailyChangePercent = prices[e.mint]?["usd_24h_change"] ?? 0.0;
      if (e.mint == nativeSol) {
        unitPrice = prices[nativeSolMint]?["usd"] ?? -1.0;
        dailyChangePercent = prices[nativeSolMint]?["usd_24h_change"] ?? 0.0;
      }
      double? usd = unitPrice >= 0 ? unitPrice * amount : null;
      return SplTokenAccountDataInfoWithUsd(
        info: e,
        usd: usd,
        account: e.account,
        usdChange: usd != null ? usd * (1 - 1 / (1 + dailyChangePercent / 100)) : null,
      );
    }).toList();
    results.sort(compoundComparator([
      (a, b) => (b.usd ?? -1).compareTo(a.usd ?? -1),
      (a, b) => b.mint.compareTo(a.mint),
    ]));
    return results;
  }

  static Future<List<String>> getTopTokens() async {
    return jsonDecode((await _httpGet(_topTokensUrl))).cast<String>();
  }

  static Future<List<List>> batchGetMetadata(List<String> addresses) async {
    if (addresses.isEmpty) return [];
    List<String> firstBatch = addresses.sublist(0, min(50, addresses.length));
    List<String> secondBatch = addresses.length > 50 ? addresses.sublist(50) : [];
    List<List> metadatas = await _httpPost("https://validator.utopiamint.xyz/token-api/token/", firstBatch).then((value) {
      Map resp = jsonDecode(value);
      if (!resp["success"]) {
        return [];
      }
      List tokens = resp["tokens"];
      return tokens.map((token) => [token["address"], token]).toList();
    });
    if (secondBatch.isNotEmpty) {
      metadatas.addAll(await(batchGetMetadata(secondBatch)));
    }
    return metadatas;
  }

  static Future<T> showLoadingDialog<T>({
    required BuildContext context,
    required Future<T> future,
    String? text,
  }) async {
    showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(text ?? S.current.loading),
            ],
          ),
        );
      },
    );
    return future.whenComplete(() {
      Navigator.of(context).pop();
    });
  }

  static Future<String?> showInputDialog({
    required BuildContext context,
    required String prompt,
    String? label,
    String? initialValue,
    String? confirmText,
  }) {
    TextEditingController controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(prompt),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx, controller.text);
              },
              child: Text(confirmText ?? S.current.ok),
            ),
          ],
        );
      },
    );
  }

  static Comparator<T> compoundComparator<T>(List<Comparator<T>> comparators) {
    return (a, b) => comparators.fold(0, (prev, cmp) => prev == 0 ? cmp(a, b) : prev);
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
              "nft INTEGER DEFAULT 0,"
              "ext_url TEXT,"
              "attributes TEXT,"
              "description TEXT,"
              "expiry INTEGER"
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

  static Future<String> _httpGet(String url) async {
    debugPrint("get $url");
    return DefaultCacheManager().downloadFile(url).then((value) => value.file.readAsString());
  }

  static Future<String> _httpPost(String url, dynamic body) async {
    debugPrint("post $url");
    return HttpClient().postUrl(Uri.parse(url)).then((HttpClientRequest request) {
      request.headers.set(HttpHeaders.contentTypeHeader, "application/json");
      request.write(jsonEncode(body));
      return request.close();
    }).then((HttpClientResponse response) {
      return response.transform(utf8.decoder).join();
    });
  }

  static Future<bool> showConfirmBottomSheet({
    required BuildContext context,
    String? title,
    String? confirmText,
    String? cancelText,
    required WidgetBuilder bodyBuilder,
  }) async {
    ThemeData themeData = Theme.of(context);
    bool? result = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: TextButtonTheme(
            data: TextButtonThemeData(
              style: TextButton.styleFrom(
                primary: themeData.colorScheme.onPrimary,
                backgroundColor: themeData.colorScheme.primary,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(40)),
                ),
                textStyle: themeData.textTheme.button?.copyWith(
                  color: themeData.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(title, style: themeData.textTheme.headline6),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: bodyBuilder(ctx),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: themeData.colorScheme.background,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                          child: Text(
                            cancelText ?? S.current.no,
                            style: TextStyle(
                              color: themeData.colorScheme.onBackground,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(true);
                          },
                          child: Text(confirmText ?? S.current.yes),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  static Future<bool> showInfoDialog({
    required BuildContext context,
    String? title,
    String? content,
    String? confirmText,
  }) async {
    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title ?? S.current.message),
          content: Text(content ?? ""),
          actions: [
            TextButton(
              child: Text(confirmText ?? S.current.ok),
              onPressed: () {
                Navigator.of(ctx).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;
  }

  static Widget wrapField({
    required ThemeData themeData,
    required Widget child,
    EdgeInsetsGeometry margin = const EdgeInsets.only(top: 16, bottom: 8),
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16),
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: themeData.colorScheme.background,
      ),
      child: child,
    );
  }
}

class TokenChanges {
  final Map<String, double> changes;
  final Map<String, SplTokenAccountDataInfo> updatedAccounts;
  final Map<String, Map<String, dynamic>?> tokens;
  final int solOffset;
  final bool error;
  final String? errorMessage;

  TokenChanges(this.changes, this.updatedAccounts, this.tokens, this.solOffset) : error = false, errorMessage = null;
  TokenChanges.error([this.errorMessage]) : changes = {}, updatedAccounts = {}, tokens = {}, solOffset = 0, error = true;

  static TokenChanges merge(List<TokenChanges> tokenChanges) {
    Map<String, double> changes = {};
    Map<String, SplTokenAccountDataInfo> updatedAccounts = {};
    Map<String, Map<String, dynamic>> tokens = {};
    int solOffset = 0;
    for (int i = 0; i < tokenChanges.length; ++i) {
      if (tokenChanges[i].error) {
        return TokenChanges.error(tokenChanges[i].errorMessage);
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

  Widget widget() {
    if (error) {
      return Text(S.current.transactionMayFailToConfirm);
    } else {
      return Column(
        children: [
          ...changes.map((key, value) {
            String mint = updatedAccounts[key]!.mint;
            // String shortMint = mint.length > 5 ? "${mint.substring(0, 5)}..." : mint;
            String symbol = tokens[mint]?["symbol"] ?? mint;
            symbol = symbol.isNotEmpty ? symbol : "${mint.substring(0, 5)}...";
            if (value != 0) {
              return MapEntry(key, Text("$symbol: ${value > 0 ? "+" : ""}${value.toStringAsFixed(6)}"));
            } else {
              return MapEntry(key, const SizedBox.shrink());
            }
          }).values,
          Text("SOL: ${solOffset > 0 ? "+" : ""}${(solOffset / lamportsPerSol).toStringAsFixed(6)}"),
        ],
      );
    }
  }

  @override
  String toString() {
    return 'TokenChanges{changes: $changes, updatedAccounts: $updatedAccounts, solOffset: $solOffset, errorMessage: $errorMessage}';
  }
}

class SplTokenAccountDataInfoWithUsd extends SplTokenAccountDataInfo {
  final double? usd;
  final double? usdChange;
  final String account;

  SplTokenAccountDataInfoWithUsd({
    required SplTokenAccountDataInfo info,
    required this.usd,
    required this.usdChange,
    required this.account,
  }) : super(
          mint: info.mint,
          state: info.state,
          isNative: info.isNative,
          tokenAmount: info.tokenAmount,
          owner: info.owner,
          delegate: info.delegate,
          delegateAmount: info.delegateAmount,
        );

  Future<String?> showDelegationWarning(BuildContext context, String symbol) async {
    bool approved = await Utils.showConfirmBottomSheet(
      context: context,
      title: S.current.delegationWarning,
      bodyBuilder: (_) => Text(sprintf(S.current.delegationWarning, [delegateAmount?.uiAmountString ?? "0", symbol, delegate ?? "someone"])),
      confirmText: S.current.revoke,
    );
    if (!approved) return null;
    Instruction ix = TokenInstruction.revoke(
      source: Ed25519HDPublicKey(base58decode(account)),
      sourceOwner: Ed25519HDPublicKey(base58decode(KeyManager.instance.pubKey)),
    );
    return Utils.showLoadingDialog(
      context: context,
      future: Utils.sendInstructions([ix]),
      text: S.current.revokingDelegation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SplTokenAccountDataInfoWithUsd &&
          runtimeType == other.runtimeType &&
          account == other.account;

  @override
  int get hashCode => account.hashCode;
}