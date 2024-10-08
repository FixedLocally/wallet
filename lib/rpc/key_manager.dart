import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:sprintf/sprintf.dart';
import 'package:sqflite/sqflite.dart';

import '../generated/l10n.dart';
import '../routes/show_secret.dart';
import '../utils/utils.dart';
import '../widgets/domain_info.dart';
import '../widgets/text.dart';
import 'errors/errors.dart';

const String derivationPathTemplate = "m/44'/501'/%s'/0'";
const List<Map<String, dynamic>> _defaultApps = [
  {
    "url": "https://solend.fi/dashboard",
    "name": "Solend",
    "last_used_ts": 0,
    "used_count": 0,
    "starred": 0
  },
  {
    "url": "https://jup.ag",
    "name": "Jupiter Aggregator",
    "last_used_ts": 0,
    "used_count": 0,
    "starred": 0
  },
  {
    "url": "https://dex.zeta.markets",
    "name": "Zeta Markets",
    "last_used_ts": 0,
    "used_count": 0,
    "starred": 0
  },
  {
    "url": "https://tulip.garden/leverage",
    "name": "Tulip",
    "last_used_ts": 0,
    "used_count": 0,
    "starred": 0
  },
  {
    "url": "https://www.orca.so/",
    "name": "Orca",
    "last_used_ts": 0,
    "used_count": 0,
    "starred": 0
  },
  {
    "url": "https://magiceden.io/",
    "name": "Magic Eden",
    "last_used_ts": 0,
    "used_count": 0,
    "starred": 0
  },
];

class KeyManager {
  static KeyManager? _instance;

  late Database _db;

  bool _ready = false;
  List<ManagedKey> _wallets = [];
  ManagedKey? _activeWallet;
  String? mockPubKey;
  final Map<String, String?> _domainLogos = {};
  List<App> _apps = [];

  static KeyManager get instance {
    _instance ??= KeyManager._();
    return _instance!;
  }

  bool get isEmpty => _wallets.isEmpty;
  bool get isNotEmpty => _wallets.isNotEmpty;
  bool get canRemoveHdWallet => _wallets.where((e) => e.keyType == "seed").length > 1;
  String get pubKey => mockPubKey ?? _activeWallet!.pubKey;
  bool get isHdWallet => mockPubKey != null ? false : _activeWallet!.keyType == "seed";
  bool get isReady => _ready && _wallets.isNotEmpty;
  String get walletName => mockPubKey != null ? S.current.mocked : _activeWallet!.name;
  List<ManagedKey> get wallets => List.unmodifiable(_wallets);
  List<App> get apps => List.unmodifiable(_apps);

  KeyManager._();

  Future<void> init() async {
    _db = await openDatabase(
      "key_manager.db",
      version: 5,
      onCreate: (Database db, int version) async {
        await db.execute(
            "CREATE TABLE wallets ("
                "id INTEGER PRIMARY KEY," // rowid (sqlite specs)
                "name TEXT," // wallet nickname
                "pubkey TEXT," // wallet nickname
                "key_type TEXT," // "seed" or "json"
                "key_hash TEXT," // secure_storage_key=`${key_type}_${key_hash}`
                "key_path TEXT," // key derivation path eg m/44'/501'/0'/0'
                "active BOOLEAN" // active wallet indicator
                ")"
        );
        await db.execute(
            "CREATE TABLE connections ("
                "id INTEGER PRIMARY KEY," // rowid (sqlite specs)
                "wallet_id INTEGER," // wallet id in wallets table
                "domain TEXT," // whitelisted domain
                "last_used_ts INTEGER" // last used timestamp
                ")"
        );
        await db.execute(
            "CREATE TABLE address_book ("
                "id INTEGER PRIMARY KEY," // rowid (sqlite specs)
                "pubkey TEXT," // wallet pubkey
                "nickname TEXT," // wallet nickname
                "last_used_ts INTEGER" // last used timestamp
                ")"
        );
        await db.execute(
            "CREATE TABLE domain_logos ("
                "domain TEXT PRIMARY KEY," // domain
                "logo_url TEXT" // logo source
                ")"
        );
        await db.execute(
          "CREATE TABLE apps ("
                "id INTEGER PRIMARY KEY," // rowid (sqlite specs)
                "url TEXT," // app url
                "name TEXT," // app name
                "last_used_ts INTEGER," // last used timestamp
                "used_count INTEGER," // used count
                "starred INTEGER" // added to favourites
                ")"
        );
        // add a few default apps
        for (final app in _defaultApps) {
          await db.insert("apps", app);
        }
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        switch (oldVersion) {
          case 1:
            await db.transaction((txn) async {
              await txn.execute(
                  "CREATE TABLE connections ("
                      "id INTEGER PRIMARY KEY," // rowid (sqlite specs)
                      "wallet_id INTEGER," // wallet id in wallets table
                      "domain TEXT" // whitelisted domain
                      ")"
              );
              await txn.execute(
                  "CREATE TABLE address_book ("
                      "id INTEGER PRIMARY KEY," // rowid (sqlite specs)
                      "pubkey TEXT," // wallet pubkey
                      "nickname TEXT," // wallet nickname
                      "last_used_ts INTEGER" // last used timestamp
                      ")"
              );
            });
            continue v2; // fall thru, continue upgrading
          v2:
          case 2:
            await db.transaction((txn) async {
              await txn.execute(
                  "ALTER TABLE connections ADD COLUMN thumbnail TEXT"
              );
              await txn.execute(
                  "ALTER TABLE connections ADD COLUMN last_used_ts INTEGER"
              );
            });
            continue v3; // fall thru, continue upgrading
          v3:
          case 3:
            await db.transaction((txn) async {
              await txn.execute("CREATE TABLE domain_logos ("
                  "domain TEXT PRIMARY KEY," // domain
                  "logo_url TEXT" // logo source
                  ")");
              // doesn't support
              // await txn.execute("ALTER TABLE connections DROP COLUMN thumbnail");
            });
            continue v4; // fall thru, continue upgrading
          v4:
          case 4:
            await db.transaction((txn) async {
              await txn.execute("CREATE TABLE apps ("
                  "id INTEGER PRIMARY KEY," // rowid (sqlite specs)
                  "url TEXT," // app url
                  "name TEXT," // app name
                  "last_used_ts INTEGER," // last used timestamp
                  "used_count INTEGER," // used count
                  "starred INTEGER" // added to favourites
                  ")");
              for (final app in _defaultApps) {
                await txn.insert("apps", app);
              }
            });
            // continue v5; // fall thru, continue upgrading
        }
      }
    );
    List<Map<String, Object?>> wallets = await _db.query("wallets");
    _wallets = wallets.map((Map<String, Object?> wallet) {
      return ManagedKey.fromJSON(wallet);
    }).toList();
    List<Map<String, Object?>> domainLogos = await _db.query("domain_logos");
    for (var element in domainLogos) {
      if (element["domain"] != null && _domainLogos[element["domain"]] == null) {
        _domainLogos[element["domain"] as String] = element["logo_url"] as String?;
      }
    }
    try {
      _activeWallet = _wallets.firstWhere((ManagedKey wallet) => wallet.active);
    } catch (e) {
      if (_wallets.isNotEmpty) {
        _activeWallet ??= _wallets.first;
      }
    }
    _db.query("apps").then((value) => value.forEach((e) => _apps.add(App.fromJSON(e))));
    _ready = true;
  }

  Future<void> insertSeed(String mnemonic, [int first = 0]) async {
    assert(_ready);
    List<int> seed = bip39.mnemonicToSeed(mnemonic);
    List<int> spareSeed = bip39.mnemonicToSeed(bip39.generateMnemonic());
    String seedHash = sha256.convert([...seed, ...spareSeed]).bytes.sublist(0, 4).map((e) => e.toRadixString(16).padLeft(2, "0")).join("");
    Ed25519HDKeyPair keypair = await compute(
      _generateKey,
      [seed, derivationPathTemplate.replaceAll("%s", "$first")],
    );
    const FlutterSecureStorage().write(
      key: "seed_$seedHash",
      value: "${seed.join(",")};$first",
    );
    const FlutterSecureStorage().write(
      key: "mnemonic_$seedHash",
      value: mnemonic,
    );
    ManagedKey newKey = ManagedKey(
      name: sprintf(S.current.walletNum, [first]),
      pubKey: keypair.publicKey.toBase58(),
      keyType: "seed",
      keyHash: seedHash,
      keyPath: derivationPathTemplate.replaceAll("%s", "$first"),
      active: true,
    );
    await _db.transaction((txn) async {
      int id = await txn.insert("wallets", newKey.toJSON());
      await txn.execute("update wallets set active=0 where id=?", [id]);
      newKey._id = id;
      _wallets.add(newKey);
      _activeWallet = newKey;
    });
  }

  Future<void> setActiveKey(ManagedKey key) async {
    assert(_ready);
    if (!_wallets.contains(key)) throw WalletError("Wallet not found");
    mockPubKey = null;
    await _db.transaction((txn) async {
      await txn.execute("update wallets set active=0");
      await txn.execute("update wallets set active=1 where id=?", [key._id]);
      for (ManagedKey key in _wallets) {
        key._active = false;
      }
      key._active = true;
      _activeWallet = key;
    });
  }

  Future<Signature> sign(List<int> message) async {
    assert(_ready);
    if (mockPubKey != null) throw SignatureError("Cannot sign with mock wallet");
    Wallet wallet = await _activeWallet!.getWallet();
    return compute(_sign, [wallet, message]);
  }

  Future<SignedTx> signMessage(Message message, String recentBlockhash) async {
    assert(_ready);
    if (mockPubKey != null) throw SignatureError("Cannot sign with mock wallet");
    Wallet? wallet = await _activeWallet!.getWallet();
    return compute(_signTx, [wallet, message, recentBlockhash]);
  }

  Future<ManagedKey> createWallet([int? overrideIndex]) async {
    // get seed
    String seedHash = _wallets.where((element) => element.keyType == "seed").map((element) => element.keyHash).first;
    String? seed = await const FlutterSecureStorage().read(key: "seed_$seedHash");
    if (seed == null) throw MissingKeyError("Key not found");
    List<String> seedSegments = seed.split(";");
    int index = 0;
    if (seedSegments.length > 1) index = int.parse(seedSegments[1]);
    ++index;
    index = overrideIndex ?? index;
    String path = derivationPathTemplate.replaceAll("%s", (index).toString());
    Wallet wallet = await compute(
      _generateKey,
      [seedSegments.first.split(",").map(int.parse).toList(), path],
    );
    const FlutterSecureStorage().write(
      key: "seed_$seedHash",
      value: "${seedSegments.first};$index",
    );
    mockPubKey = null;
    return await _db.transaction((txn) async {
      ManagedKey newKey = ManagedKey(
        name: sprintf(S.current.walletNum, [index]),
        pubKey: wallet.publicKey.toBase58(),
        keyType: "seed",
        keyHash: seedHash,
        keyPath: path,
        active: true,
      );
      await txn.execute("update wallets set active=0");
      for (ManagedKey key in _wallets) {
        key._active = false;
      }
      int id = await txn.insert("wallets", newKey.toJSON());
      newKey._id = id;
      _wallets.add(newKey);
      _activeWallet = newKey;
      return newKey;
    });
  }

  Future<void> renameWallet(String name) async {
    return _db.transaction((txn) async {
      await txn.execute("update wallets set name=? where id=?", [name, _activeWallet!._id]);
      _activeWallet = ManagedKey._(
        _activeWallet!._id,
        name: name,
        pubKey: _activeWallet!.pubKey,
        keyType: _activeWallet!.keyType,
        keyHash: _activeWallet!.keyHash,
        keyPath: _activeWallet!.keyPath,
        active: true,
      );
    });
  }

  Future<ManagedKey> importWallet(List<int> privateKey) async {
    // get seed
    String keyHash = privateKey.hashCode.toRadixString(16).padLeft(8, "0").substring(0, 8);
    const FlutterSecureStorage().write(
      key: "key_$keyHash",
      value: privateKey.join(","),
    );
    mockPubKey = null;
    Wallet wallet = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: privateKey);
    return await _db.transaction((txn) async {
      ManagedKey newKey = ManagedKey(
        name: S.current.importedWallet,
        pubKey: wallet.publicKey.toBase58(),
        keyType: "key",
        keyHash: keyHash,
        keyPath: "",
        active: true,
      );
      await txn.execute("update wallets set active=0");
      for (ManagedKey key in _wallets) {
        key._active = false;
      }
      int id = await txn.insert("wallets", newKey.toJSON());
      newKey._id = id;
      _wallets.add(newKey);
      _activeWallet = newKey;
      return newKey;
    });
  }

  String? getDomainLogo(String domain) {
    return _domainLogos[domain];
  }

  Future<void> setDomainLogo(String domain, String logoUrl) async {
    _domainLogos[domain] = logoUrl;
    return _db.transaction((txn) async {
      // upsert
      await txn.rawUpdate("insert into domain_logos (logo_url, domain) values (?, ?) on conflict(domain) do update set logo_url=?", [logoUrl, domain, logoUrl]);
    });
  }

  Future<void> requestRemoveWallet(BuildContext context, ManagedKey? managedKey) async {
    late String msg;
    if (KeyManager.instance.isHdWallet && !KeyManager.instance.canRemoveHdWallet) return;
    if (KeyManager.instance.isHdWallet) {
      msg = S.current.removeHdWalletContent;
    } else {
      msg = S.current.removeKeyWalletContent;
    }
    bool confirm = await Utils.showConfirmBottomSheet(
      context: context,
      title: S.current.removeWallet,
      bodyBuilder: (_) => Text(msg),
      confirmText: S.current.delete,
    );
    if (!confirm) {
      return;
    }
    await KeyManager.instance.removeWallet(managedKey);
  }

  Future<void> removeWallet([ManagedKey? key]) async {
    // get seed
    key ??= _activeWallet;
    if (_wallets.length <= 1) return;
    return await _db.transaction((txn) async {
      await txn.execute("delete from wallets where id=?", [key!.id]);
      _wallets.remove(key);
      if (key.active) {
        if (_wallets.isNotEmpty) {
          _activeWallet = _wallets.first;
        } else {
          _activeWallet = null;
        }
        _activeWallet?._active = true;
        await txn.execute("update wallets set active=1 where id=?", [_activeWallet!.id]);
      }
    });
  }

  Future<bool> authenticateUser(BuildContext context) async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      return auth.authenticate(
        localizedReason: S.current.pleaseAuthenticateToContinue,
        options: AuthenticationOptions(stickyAuth: true),
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestConnect(BuildContext context, String domain, String title, List<String> logoUrls, bool onlyIfTrusted) async {
    if (mockPubKey != null) return true;
    List l = await _db.query("connections", where: "domain=? and wallet_id=?", whereArgs: [domain, _activeWallet!.id]);
    if (l.isEmpty) {
      if (onlyIfTrusted) return false;
      bool approve = await Utils.showConfirmBottomSheet(
        context: context,
        // title: S.current.connectWallet,
        confirmText: S.current.connect,
        bodyBuilder: (_) {
          return Column(
            children: [
              SizedBox(height: 8),
              DomainInfoWidget(
                domain: domain,
                logoUrls: logoUrls,
                title: title,
              ),
              SizedBox(height: 16),
              HighlightedText(
                text: sprintf(S.current.connectWalletHeadline,
                    [_activeWallet!.name]),
              ),
              Text(S.current.connectWalletContent),
            ],
          );
        },
        cancelText: S.current.cancel,
      );
      if (approve) {
        await _didConnect(domain, title);
      } else {
        return false;
      }
    } else {
      _didConnect(domain, title);
    }
    return true;
  }

  Future<void> _didConnect(String domain, String title) async {
    await _db.transaction((txn) async {
      txn.insert("connections", {
        "domain": domain,
        "wallet_id": _activeWallet!.id,
        "last_used_ts": DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
      // todo could give every app a "weight" to determine usage frequency
      txn.query("apps", where: "url like ?", whereArgs: ["https://$domain%"]).then((apps) async {
        if (apps.isNotEmpty) {
          for (Map app in apps) {
            txn.update(
              "apps",
              {
                "last_used_ts": DateTime.now().millisecondsSinceEpoch ~/ 1000,
                "used_count": app["used_count"] + 1,
                "name": title,
              },
              where: "id=?",
              whereArgs: [app["id"]],
            );
          }
        } else {
          debugPrint("installing app $domain");
          int id = await txn.insert("apps", {
            "url": "https://$domain",
            "name": title,
            "last_used_ts": DateTime.now().millisecondsSinceEpoch ~/ 1000,
            "used_count": 1,
            "starred": 0,
          });
          _apps.add(App(
            id: id,
            url: "https://$domain",
            name: title,
            lastUsedTs: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            usedCount: 1,
            starred: false,
          ));
        }
      });
    });
  }

  Future<void> removeDapp(int id) async {
    await _db.transaction((txn) async {
      txn.delete("apps", where: "id=?", whereArgs: [id]);
    });
    _apps = _apps.where((element) => element.id != id).toList();
  }

  Future<void> requestShowRecoveryPhrase(BuildContext context) async {
    if (await authenticateUser(context) == false) return;
    NavigatorState nav = Navigator.of(context);
    String seedHash = _activeWallet!.keyHash;
    String mnemonic = (await Utils.showLoadingDialog(context: context, future: const FlutterSecureStorage().read(key: "mnemonic_$seedHash"))) ?? List.generate(12, (index) => "??").join(" ");
    nav.push(MaterialPageRoute(
      builder: (ctx) {
        return ShowSecretRoute(
          title: S.current.exportSecretRecoveryPhrase,
          secret: mnemonic,
          copySuccessMessage: S.current.copySeedSuccess,
          header: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.33),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(S.current.seedPhraseWarning),
          ),
        );
      },
      settings: const RouteSettings(name: "/show_secret"),
    ));
  }

  Future<void> requestShowPrivateKey(BuildContext context) async {
    if (await authenticateUser(context) == false) return;
    NavigatorState nav = Navigator.of(context);
    Wallet wallet = await Utils.showLoadingDialog(context: context, future: _activeWallet!.getWallet());
    List<int> key = (await wallet.extract()).bytes;
    key += wallet.publicKey.bytes;
    String keyBase58 = base58encode(key);
    nav.push(MaterialPageRoute(
      builder: (ctx) {
        return ShowSecretRoute(
          title: S.current.exportPrivateKey,
          secret: keyBase58,
          copySuccessMessage: S.current.copyPrivateKeySuccess,
          header: Utils.wrapWarning(
            context: context,
            child: Text(S.current.showPrivateKeyContent),
          ),
        );
      },
      settings: const RouteSettings(name: "/show_secret"),
    ));
  }

  Future<void> clearConnectionHistory() async {
    await _db.delete("connections", where: "wallet_id=?", whereArgs: [_activeWallet!.id]);
  }
}

class ManagedKey {
  int _id = -1;
  bool _active;

  int get id => _id;
  bool get active => _active;

  final String name;
  final String pubKey;
  final String keyType;
  final String keyHash;
  final String keyPath;

  ManagedKey({
    required this.name,
    required this.pubKey,
    required this.keyType,
    required this.keyHash,
    required this.keyPath,
    bool active = false,
  }) : _active = active;

  ManagedKey._(
    this._id, {
    required this.name,
    required this.pubKey,
    required this.keyType,
    required this.keyHash,
    required this.keyPath,
    required bool active,
  }) : _active = active;

  factory ManagedKey.fromJSON(Map<String, Object?> m) {
    return ManagedKey._(
      m["id"] as int,
      name: m["name"] as String,
      pubKey: m["pubkey"] as String,
      keyType: m["key_type"] as String,
      keyHash: m["key_hash"] as String,
      keyPath: m["key_path"] as String,
      active: m["active"] as int != 0,
    );
  }

  Future<Wallet> getWallet() async {
    late Wallet wallet;
    switch (keyType) {
      case "seed":
        // get seed
        String? seed = await const FlutterSecureStorage().read(key: "seed_$keyHash");
        if (seed == null) throw MissingKeyError("Key not found");
        List<String> seedSegments = seed.split(";");
        wallet = await compute(
          _generateKey,
          [seedSegments.first.split(",").map(int.parse).toList(), keyPath],
        );
        return wallet;
      case "key":
        // get key
        String? key = await const FlutterSecureStorage().read(key: "key_$keyHash");
        if (key == null) throw MissingKeyError("Key not found");
        wallet = await Wallet.fromPrivateKeyBytes(privateKey: key.split(",").map(int.parse).toList());
        return wallet;
    }
    throw MissingKeyError("keyType not supported");
  }

  Map<String, Object?> toJSON() {
    return {
      "id": id < 0 ? null : id,
      "name": name,
      "pubkey": pubKey,
      "key_type": keyType,
      "key_hash": keyHash,
      "key_path": keyPath,
      "active": active ? 1 : 0,
    };
  }

  @override
  String toString() {
    return 'ManagedKey{name: $name, pubKey: $pubKey, active: $active}';
  }
}

class App {
  /*
    "url": "https://magiceden.io/",
    "name": "Magic Eden",
    "last_used_ts": 0,
    "used_count": 0,
    "starred": 0
   */
  final int id;
  final String url;
  final String name;
  final int lastUsedTs;
  final int usedCount;
  final bool starred;

  const App({
    required this.id,
    required this.url,
    required this.name,
    required this.lastUsedTs,
    required this.usedCount,
    required this.starred,
  });

  factory App.fromJSON(Map<String, Object?> m) {
    return App(
      id: m["id"] as int,
      url: m["url"] as String,
      name: m["name"] as String,
      lastUsedTs: m["last_used_ts"] as int,
      usedCount: m["used_count"] as int,
      starred: m["starred"] as int != 0,
    );
  }
}

Future<Ed25519HDKeyPair> _generateKey(List args) async {
  return Ed25519HDKeyPair.fromSeedWithHdPath(seed: args[0], hdPath: args[1]);
}

Future<Signature> _sign(List args) async {
  Wallet wallet = args[0];
  List<int> message = args[1];
  return await wallet.sign(message);
}

Future<SignedTx> _signTx(List args) async {
  Wallet wallet = args[0];
  Message message = args[1];
  String recentBlockhash = args[2];
  return await wallet.signMessage(message: message, recentBlockhash: recentBlockhash);
}
