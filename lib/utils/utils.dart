import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart' hide Instruction;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:sprintf/sprintf.dart';
import 'package:sqflite/sqflite.dart';

import '../generated/l10n.dart';
import '../models/models.dart';
import '../routes/popups/bottom_sheet.dart';
import '../rpc/constants.dart';
import '../rpc/key_manager.dart';
import '../widgets/text.dart';
import 'extensions.dart';

const String _topTokensUrl = "https://cache.jup.ag/top-tokens";
const String _priceApiUrl = "https://api.hanabi.so/price/";
const String _tokenMetadataApiUrl = "https://api.hanabi.so/token/";
const String _simulateApiUrl = "https://api.hanabi.so/simulate/";
const String _yieldApiUrl = "https://api.hanabi.so/yield";
const nativeSol = "native-sol";
const wrappedSolMint = "So11111111111111111111111111111111111111112";
const usdcMint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v";

class Utils {
  static final SolanaClient _solanaClient = SolanaClient(
    rpcUrl: RpcConstants.kRpcUrl,
    websocketUrl: RpcConstants.kWsUrl,
  );

  static String _injectionJs = "";
  static Completer<void>? _completer;
  static Database? _db;
  static SharedPreferences? _prefs;

  static String get injectionJs => _injectionJs;
  static SharedPreferences get prefs => _prefs!;

  static Future loadAssets() async {
    if (_injectionJs.isNotEmpty) return;
    if (_completer != null) return;
    _completer = Completer<void>();
    Future f1 = _openDatabase().then((value) => _db = value);
    Future f2 = rootBundle.loadString('assets/inject.js').then((String js) {
      _injectionJs = js;
    });

    Future f3 = KeyManager.instance.init();
    Future f4 = SharedPreferences.getInstance().then((value) => _prefs = value);
    Future.wait([f1, f2, f3, f4]).then((value) => _completer!.complete(null));
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
    //   Map resp = jsonDecode(await _httpGet("https://api.hanabi.so/token/$token"));
    //   return [token, resp["success"] ? resp["token"] : null];
    // }).toList();
    // List<List> metadatas = await Future.wait(futures);
    List<List> metadatas = await batchGetMetadata(remainingTokens);
    debugPrint("got metadatas ${metadatas.length}");
    metadatas.map((e) => e[1]["attributes"] = jsonEncode(e[1]["attributes"])).toList();
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
                "sus": metadataMap["sus"] == true ? 1 : 0,
                "mint": metadataMap["address"],
                "symbol": metadataMap["symbol"],
                "name": metadataMap["name"],
                "decimals": metadataMap["decimals"],
                "image": metadataMap["image"],
                "nft": metadataMap["nft"],
                "ext_url": metadataMap["externalUrl"],
                "attributes": metadataMap["attributes"],
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
    BigInt amount = BigInt.from(Int8List.fromList(data.sublist(64, 72)).buffer.asUint64List().first);
    if (amount < BigInt.zero) amount += BigInt.parse("10000000000000000", radix: 16);
    List<int> rawDelegate = data.sublist(72, 108);
    String? delegate = rawDelegate.sublist(0, 4).any((e) => e != 0) ? base58encode(rawDelegate.sublist(4)) : null;
    List<int> rawState = data.sublist(108, 109);
    List<int> rawIsNative = data.sublist(109, 121);
    bool isNative = rawIsNative.sublist(0, 4).any((e) => e != 0);
    BigInt rawDelegatedAmount = BigInt.from(Int8List.fromList(data.sublist(121, 129)).buffer.asUint64List().first);
    if (rawDelegatedAmount < BigInt.zero) rawDelegatedAmount += BigInt.parse("10000000000000000", radix: 16);
    BigInt? delegatedAmount = delegate != null ? rawDelegatedAmount : null;
    // List<int> _closeAuthority = data.sublist(129, 165);
    // String? closeAuthority = _closeAuthority.sublist(0, 4).any((e) => e != 0) ? base58encode(_closeAuthority.sublist(4)) : null;
    AccountResult mintAcct = await _solanaClient.rpcClient.getAccountInfo(
      mint,
      commitment: Commitment.confirmed,
      encoding: Encoding.base64,
    );
    // https://github.com/solana-labs/solana-program-library/blob/48fbb5b7/token/js/src/state/mint.ts#L43
    int decimals = (mintAcct.value?.data as BinaryAccountData).data[4 + 32 + 8];
    return SplTokenAccountDataInfo(
      mint: mint,
      owner: owner,
      tokenAmount: TokenAmount(amount: "$amount", decimals: decimals, uiAmountString: amount.addDecimals(decimals)),
      delegate: delegate,
      state: "${rawState[0]}",
      isNative: isNative,
      delegateAmount: delegatedAmount != null ? TokenAmount(amount: "$delegatedAmount", decimals: decimals, uiAmountString: delegatedAmount.addDecimals(decimals)) : null,
      // closeAuthority: closeAuthority,
    );
  }

  // get accounts in batches of 10
  static Future<List<Account?>> batchGetAccounts(List<String> addresses) async {
    List<Account?> accounts = [];
    for (int i = 0; i < addresses.length; i += 50) {
      List<String> batch = addresses.sublist(i, min(i + 50, addresses.length));
      accounts.addAll((await _solanaClient.rpcClient.getMultipleAccounts(batch, commitment: Commitment.confirmed, encoding: Encoding.base64)).value);
    }
    return accounts;
  }

  static Future<TokenChanges> simulateTx(List<int> rawMessage, String owner) async {
    Map<String, dynamic> result = json.decode(await _httpPost(_simulateApiUrl, {
      "payload": base64Encode(rawMessage),
      "subject": owner,
    }));
    print("simulate result $result");
    if (result["success"] == false) {
      return TokenChanges.error(result["error"], false);
    }
    int solOffset = 0;
    Map<String, double> changes = {};
    Map<String, List<Delegation>> delegations = {};
    List<dynamic> resultChanges = result["changes"];
    List<String> mints = [];
    for (Map<String, dynamic> change in resultChanges) {
      String address = change["account"];
      String mint = change["mint"];
      int before = int.parse(change["balanceBefore"]);
      int after = int.parse(change["balanceAfter"]);
      int delegatedAmount = int.parse(change["delegateAmount"] ?? "0");
      String delegate = change["delegateAfter"];
      if (change["authorityBefore"] != owner) before = 0;
      if (change["authorityAfter"] != owner) after = 0;
      int diff = after - before;
      if (address == owner) {
        solOffset += diff;
      } else {
        changes[mint] = (changes[mint] ?? 0) + diff;
      }
      if (delegatedAmount > 0) {
        delegations[mint] = (delegations[mint] ?? []) + [Delegation(delegate, delegatedAmount.toDouble())];
      }
      mints.add(mint);
    }
    Map<String, Map<String, dynamic>?> tokens = await getTokens(mints);
    for (String mint in mints) {
      if (tokens[mint] != null && changes[mint] != null) {
        changes[mint] = changes[mint]! / pow(10, tokens[mint]!["decimals"]);
      }
      if (tokens[mint] != null && delegations[mint] != null) {
        delegations[mint] = delegations[mint]!.map((e) => Delegation(e.delegate, e.amount / pow(10, tokens[mint]!["decimals"]))).toList();
      }
    }
    print(changes);
    print(delegations);
    return TokenChanges(changes, delegations, {}, tokens, solOffset);
    // return TokenChanges(changes, delegations, updatedAcctsMap, await getTokens(updatedAcctsMap.values.map((e) => e.mint).toList()), postSolBalance - preSolBalance);
  }

  static Future<TokenChanges> simulateVersionedTx(List<int> rawMessage, String owner) async {
    // todo actually deseralise it
    return simulateTx(rawMessage, owner);
  }

  static Future<List<TokenChanges>> simulateTxs(List<List<int>> rawMessage, String owner, List<int> versions) async {
    List<TokenChanges> changes = [];
    if (rawMessage.length > 10) {
      return [TokenChanges.error("tooManyTransactions:${rawMessage.length}", true)];
    }
    for (int i = 0; i < rawMessage.length; ++i) {
      // sequentially
      if (versions[i] >= 0) {
        changes.add(await simulateVersionedTx(rawMessage[i], owner));
      } else {
        changes.add(await simulateTx(rawMessage[i], owner));
      }
    }
    return changes;
  }

  static Future<LatestBlockhash> getBlockhash() async {
    return await _solanaClient.rpcClient.getLatestBlockhash(commitment: Commitment.confirmed).then((value) => value.value);
  }

  static Future<String> sendTransaction(SignedTx tx, {Commitment preflightCommitment = Commitment.confirmed, bool skipPreflight = false}) async {
    return _solanaClient.rpcClient.sendTransaction(
      tx.encode(),
      preflightCommitment: preflightCommitment,
      skipPreflight: skipPreflight,
    );
  }

  static Future<String> sendInstructions(List<Instruction> ixs , {Commitment preflightCommitment = Commitment.confirmed}) async {
    Message msg = Message(instructions: ixs);
    LatestBlockhash blockhash = await Utils.getBlockhash();
    SignedTx tx = await KeyManager.instance.signMessage(msg, blockhash.blockhash);
    String sig = await Utils.sendTransaction(tx);
    await Utils.confirmTransaction(sig);
    return sig;
  }

  static Future<Account?> getAccount(
    String pubkey, {
    Commitment commitment = Commitment.confirmed,
    Encoding encoding = Encoding.base64,
    DataSlice? dataSlice,
  }) async {
    return _solanaClient.rpcClient.getAccountInfo(pubkey, commitment: commitment, encoding: encoding, dataSlice: dataSlice).then((value) => value.value);
  }

  static Future<VoteAccounts> getVoteAccounts() {
    return _solanaClient.rpcClient.getVoteAccounts(keepUnstakedDelinquents: false, delinquentSlotDistance: 128);
  }

  static Future<List<ProgramAccount>> getStakeAccounts(String pubkey) {
    return _solanaClient.rpcClient.getProgramAccounts(
      StakeProgram.programId,
      encoding: Encoding.jsonParsed,
      filters: [
        ProgramDataFilter.memcmpBase58(offset: 44, bytes: pubkey), // withdraw auth match
      ],
    ).then((value) {
      return value.where((e) => e.account.data is ParsedStakeProgramAccountData)
          .toList();
    });
  }

  static Future<int> getCurrentEpoch() {
    return _solanaClient.rpcClient.getEpochInfo().then((value) => value.epoch);
  }

  static Future<List<ProgramAccount>> getValidatorInfo() {
    return _solanaClient.rpcClient.getProgramAccounts("Config1111111111111111111111111111111111111", encoding: Encoding.jsonParsed);
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
    Map<String, dynamic> prices = {};
    Map<String, dynamic> json = jsonDecode(await _httpPost(_priceApiUrl, tokens));
    if (json["success"] == true) {
      prices = json["tokens"] ?? {};
    }
    return prices;
  }

  static Future<List<SplTokenAccountDataInfoWithUsd>> getBalances(String pubKey) async {
    List<SplTokenAccountDataInfoWithUsd> rawResults = [];
    List<ProgramAccount> accounts = await _solanaClient.rpcClient.getTokenAccountsByOwner(
      pubKey,
      const TokenAccountsFilter.byProgramId(TokenProgram.programId),
      encoding: Encoding.jsonParsed,
      commitment: Commitment.confirmed,
    ).then((value) => value.value);
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
    int lamports = await _solanaClient.rpcClient.getBalance(pubKey, commitment: Commitment.confirmed).then((value) => value.value);
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
    mints.add(wrappedSolMint);
    Map<String, dynamic> prices = await _getCoinGeckoPrices(mints.toList());
    List<SplTokenAccountDataInfoWithUsd> results = rawResults.map((e) {
      String uiAmountString = e.tokenAmount.uiAmountString ?? "0";
      double amount = double.parse(uiAmountString);
      num unitPrice = prices[e.mint]?["usd"] ?? -1.0;
      num dailyChangePercent = prices[e.mint]?["usd_24h_change"] ?? 0.0;
      if (e.mint == nativeSol) {
        unitPrice = prices[wrappedSolMint]?["usd"] ?? -1.0;
        dailyChangePercent = prices[wrappedSolMint]?["usd_24h_change"] ?? 0.0;
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

  static Future<List<int>> getSolBalances(List<String> addresses) async {
    return _solanaClient.rpcClient.getMultipleAccounts(addresses).then((value) {
      return value.value.map((e) => e?.lamports ?? 0).toList();
    });
  }

  static Future<List<YieldOpportunity>> getYieldOpportunities(String mint) async {
    Map resp = jsonDecode(await httpGet("$_yieldApiUrl/$mint"));
    return resp["yield"].map<YieldOpportunity>((e) => YieldOpportunity.fromJson(e)).toList();
  }

  static Future<List<String>> getYieldableTokens() async {
    // Map resp = jsonDecode(await httpGet("$_yieldApiUrl/all"));
    // return resp["tokens"].cast<String>();
    return [];
  }

  static Future<List<String>> getTopTokens() async {
    return jsonDecode((await httpGet(_topTokensUrl, cache: true))).cast<String>();
  }

  static Future<List<List>> batchGetMetadata(List<String> addresses) async {
    if (addresses.isEmpty) return [];
    List<String> firstBatch = addresses.sublist(0, min(50, addresses.length));
    List<String> secondBatch = addresses.length > 50 ? addresses.sublist(50) : [];
    List<List> metadatas = await _httpPost(_tokenMetadataApiUrl, firstBatch).then((value) {
      Map resp = jsonDecode(value);
      if (!resp["success"]) {
        return [];
      }
      List tokens = resp["tokens"];
      return tokens.where((element) => element != null).map((token) => [token["address"], token]).toList();
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
    NavigatorState nav = Navigator.of(context);
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
      nav.pop();
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
      version: 2,
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
              "sus INTEGER DEFAULT 0,"
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
              "sus": 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        switch (oldVersion) {
          case 1:
            await db.execute("ALTER TABLE token ADD COLUMN sus INTEGER DEFAULT 0");
        }
      },
    );
  }

  static Future<String> httpGet(String url, {bool cache = false}) async {
    debugPrint("get $url");
    if (cache) {
      return DefaultCacheManager().downloadFile(url).then((value) => value.file.readAsString());
    }
    return HttpClient().getUrl(Uri.parse(url)).then((HttpClientRequest request) {
      return request.close();
    }).then((HttpClientResponse response) {
      if (response.statusCode == 200) {
        return response.transform(utf8.decoder).join();
      } else {
        return "{\"success\":false}";
      }
    });
    // return DefaultCacheManager().downloadFile(url).then((value) => value.file.readAsString());
  }

  static Future<String> _httpPost(String url, dynamic body) async {
    debugPrint("post $url");
    return HttpClient().postUrl(Uri.parse(url)).then((HttpClientRequest request) {
      request.headers.set(HttpHeaders.contentTypeHeader, "application/json");
      request.write(jsonEncode(body));
      return request.close();
    }).then((HttpClientResponse response) {
      if (response.statusCode == 200) {
        return response.transform(utf8.decoder).join();
      } else {
        return "{\"success\":false}";
      }
    });
  }

  static Future<bool> showConfirmBottomSheet({
    required BuildContext context,
    String? title,
    String? confirmText,
    String? cancelText,
    String? doubleConfirm,
    required WidgetBuilder bodyBuilder,
  }) async {
    bool? result = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ConfirmBottomSheet(
          bodyBuilder: bodyBuilder,
          title: title,
          confirmText: confirmText,
          cancelText: cancelText,
          doubleConfirm: doubleConfirm,
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
    required Color wrapColor,
    required Widget child,
    EdgeInsetsGeometry margin = const EdgeInsets.only(top: 16, bottom: 8),
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16),
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: wrapColor,
      ),
      child: child,
    );
  }

  static Widget wrapWarning({
    required BuildContext context,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withOpacity(0.33),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class TokenChanges {
  final Map<String, double> changes;
  final Map<String, List<Delegation>> delegations;
  final Map<String, SplTokenAccountDataInfo> updatedAccounts;
  final Map<String, Map<String, dynamic>?> tokens;
  final int solOffset;
  final bool error;
  final bool warning;
  final String? errorMessage;

  TokenChanges(this.changes, this.delegations, this.updatedAccounts, this.tokens, this.solOffset) : error = false, errorMessage = null, warning = false;
  TokenChanges.error([this.errorMessage, this.warning = false]) : changes = {}, delegations = {}, updatedAccounts = {}, tokens = {}, solOffset = 0, error = true;

  static TokenChanges merge(List<TokenChanges> tokenChanges) {
    Map<String, double> changes = {};
    Map<String, List<Delegation>> delegations = {};
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
      tokenChanges[i].delegations.forEach((key, value) {
        delegations[key] = (delegations[key] ?? []) + value;
      });
      solOffset += tokenChanges[i].solOffset;
    }
    return TokenChanges(changes, delegations, updatedAccounts, tokens, solOffset);
  }

  Widget widget(BuildContext context) {
    if (error) {
      if (errorMessage?.startsWith("tooManyTransactions") == true) {
        int count = int.parse(errorMessage!.split(":")[1]);
        return Column(
          children: [
            Utils.wrapWarning(context: context, child: Text(sprintf(S.current.bulkTxWarning, [count]))),
            Text(S.current.transactionMayFailToConfirm),
          ],
        );
      }
      return Text(S.current.transactionMayFailToConfirm);
    } else {
      return Column(
        children: [
          ...delegations.map((key, value) {
            String mint = key;
            // String shortMint = mint.length > 5 ? "${mint.substring(0, 5)}..." : mint;
            String symbol = tokens[mint]?["symbol"] ?? mint;
            symbol = symbol.isNotEmpty ? symbol : "${mint.substring(0, 5)}...";
            return MapEntry(
              key,
              Column(
                children: value.map((e) {
                  return HighlightedText(
                    text: sprintf(S.current.approveToTransfer, [
                      e.amount.toFixedTrimmed(6),
                      symbol,
                      // updatedAccounts[key]?.delegate?.shortened
                      e.delegate.shortened,
                    ]),
                    highlightStyle: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                    normalStyle: TextStyle(color: Colors.amber),
                    textAlign: TextAlign.center,
                  );
                }).toList(),
              ),
            );
          }).values,
          HighlightedText(
            text: "SOL: #${solOffset > 0 ? "+" : ""}${(solOffset / lamportsPerSol).toStringAsFixed(6)}#",
            highlightStyle: TextStyle(
              color: solOffset > 0 ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          ...changes.map((key, value) {
            String mint = key;
            // String shortMint = mint.length > 5 ? "${mint.substring(0, 5)}..." : mint;
            String symbol = tokens[mint]?["symbol"] ?? mint;
            symbol = symbol.isNotEmpty ? symbol : "${mint.substring(0, 5)}...";
            if (value != 0) {
              return MapEntry(
                key,
                HighlightedText(
                  text: "$symbol: #${value > 0 ? "+" : ""}${value.toStringAsFixed(6)}#",
                  highlightStyle: TextStyle(
                    color: value > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            } else {
              return MapEntry(key, const SizedBox.shrink());
            }
          }).values,
        ],
      );
    }
  }

  @override
  String toString() {
    return 'TokenChanges{changes: $changes, updatedAccounts: $updatedAccounts, solOffset: $solOffset, errorMessage: $errorMessage}';
  }
}

class Delegation {
  final String delegate;
  final double amount;

  Delegation(this.delegate, this.amount);

  @override
  String toString() {
    return 'Delegation{delegate: $delegate, amount: $amount}';
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

  List<Instruction> burnAndCloseIxs() {
    List<Instruction> ixs = [];
    if (tokenAmount.amount != "0" && mint != wrappedSolMint) {
      ixs.add(TokenInstruction.burn(
        amount: int.parse(tokenAmount.amount),
        accountToBurnFrom: Ed25519HDPublicKey(base58decode(account)),
        mint: Ed25519HDPublicKey(base58decode(mint)),
        owner: Ed25519HDPublicKey(base58decode(owner)),
      ));
    }
    ixs.add(TokenInstruction.closeAccount(
      accountToClose: Ed25519HDPublicKey(base58decode(account)),
      destination: Ed25519HDPublicKey(base58decode(owner)),
      owner: Ed25519HDPublicKey(base58decode(owner)),
    ));
    return ixs;
  }
  
  String burnAndCloseMessage() {
    if (mint == wrappedSolMint) {
      return S.current.unwrappingSol;
    }
    if (tokenAmount.amount != "0") {
      return S.current.burningTokens;
    }
    return S.current.closingAccount;
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
