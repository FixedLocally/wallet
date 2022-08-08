import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:sqflite/sqflite.dart';

import 'errors/errors.dart';

const String derivationPathTemplate = "m/44'/501'/%s'/0'";

class KeyManager {
  static KeyManager? _instance;

  late Database _db;

  bool _ready = false;
  List<ManagedKey> _wallets = [];
  ManagedKey? _activeWallet;

  static KeyManager get instance {
    _instance ??= KeyManager._();
    return _instance!;
  }

  bool get isEmpty => _wallets.isEmpty;
  bool get isNotEmpty => _wallets.isNotEmpty;
  String get pubKey => _activeWallet!.pubKey;
  List<ManagedKey> get wallets => List.unmodifiable(_wallets);

  KeyManager._();

  Future<void> init() async {
    _db = await openDatabase(
      "key_manager.db",
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(
          "CREATE TABLE wallets ("
          "id INTEGER PRIMARY KEY," // rowid (sqlite specs)
          "name TEXT," // wallet nickname
          "pubkey TEXT," // wallet nickname
          "key_type TEXT," // "seed" or "json"
          "key_hash TEXT," // secure_storage_key=`${key_type}_${key_hash}`
          "key_path TEXT," // key derivation path eg m/44'/501'/0'/0'
          "active BOOLEAN"
          ")"
        );
      },
    );
    List<Map<String, Object?>> wallets = await _db.query("wallets");
    _wallets = wallets.map((Map<String, Object?> wallet) {
      return ManagedKey.fromJSON(wallet);
    }).toList();
    try {
      _activeWallet = _wallets.firstWhere((ManagedKey wallet) => wallet.active);
    } catch (e) {
      if (_wallets.isNotEmpty) {
        _activeWallet ??= _wallets.first;
      }
    }
    _ready = true;
  }

  Future<void> insertSeed(List<int> seed) async {
    assert(_ready);
    String seedHash = sha256.convert(seed).bytes.sublist(0, 4).map((e) => e.toRadixString(16).padLeft(2, "0")).join("");
    Ed25519HDKeyPair keypair = await compute(
      _generateKey,
      [seed, derivationPathTemplate.replaceAll("%s", "0")],
    );
    const FlutterSecureStorage().write(
      key: "seed_$seedHash",
      value: "${seed.join(",")};0",
    );
    ManagedKey newKey = ManagedKey(
      name: "Wallet ${_wallets.length + 1}",
      pubKey: keypair.publicKey.toBase58(),
      keyType: "seed",
      keyHash: seedHash,
      keyPath: derivationPathTemplate.replaceAll("%s", "0"),
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
    assert(_wallets.contains(key));
    await _db.transaction((txn) async {
      await txn.execute("update wallets set active=0");
      await txn.execute("update wallets set active=1 where id=?", [key._id]);
      _activeWallet = key;
    });
  }

  Future<Signature> sign(List<int> message) async {
    assert(_ready);
    Wallet wallet = await _activeWallet!.getWallet();
    return wallet.sign(message);
  }

  Future<SignedTx> signMessage(Message message, String recentBlockhash) async {
    assert(_ready);
    Wallet? wallet = await _activeWallet!.getWallet();
    return wallet.signMessage(message: message, recentBlockhash: recentBlockhash);
  }

  Future<ManagedKey> createWallet() async {
    // get seed
    String seedHash = _wallets.where((element) => element.keyType == "seed").map((element) => element.keyHash).first;
    String? seed = await const FlutterSecureStorage().read(key: "seed_$seedHash");
    if (seed == null) throw MissingKeyError("keyHash not found");
    List<String> seedSegments = seed.split(";");
    int index = 0;
    if (seedSegments.length > 1) index = int.parse(seedSegments[1]);
    ++index;
    String path = derivationPathTemplate.replaceAll("%s", index.toString());
    Wallet wallet = await compute(
      _generateKey,
      [seedSegments.first.split(",").map(int.parse).toList(), path],
    );
    const FlutterSecureStorage().write(
      key: "seed_$seedHash",
      value: "${seedSegments.first};$index",
    );
    return await _db.transaction((txn) async {
      ManagedKey newKey = ManagedKey(
        name: "Wallet ${_wallets.length + 1}",
        pubKey: wallet.publicKey.toBase58(),
        keyType: "seed",
        keyHash: seedHash,
        keyPath: path,
        active: true,
      );
      await txn.execute("update wallets set active=0");
      _wallets.forEach((ManagedKey key) {
        key._active = false;
      });
      int id = await txn.insert("wallets", newKey.toJSON());
      newKey._id = id;
      _wallets.add(newKey);
      _activeWallet = newKey;
      return newKey;
    });
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
        if (seed == null) throw MissingKeyError("keyHash not found");
        List<String> seedSegments = seed.split(";");
        wallet = await compute(
          _generateKey,
          [seedSegments.first.split(",").map(int.parse).toList(), keyPath],
        );
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

Future<Ed25519HDKeyPair> _generateKey(List args) async {
  return Ed25519HDKeyPair.fromSeedWithHdPath(seed: args[0], hdPath: args[1]);
}
