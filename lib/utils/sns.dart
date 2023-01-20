import 'package:crypto/crypto.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';

import 'utils.dart';

// ignore_for_file: constant_identifier_names
/// namesLPneVptA9Z5rqUDD9tMTWEJwofgaYwp8cawRkX
const Ed25519HDPublicKey _nameProgramId = Ed25519HDPublicKey([0x0b, 0xad, 0x51, 0xf4, 0x13, 0xc1, 0xf3, 0xa9, 0x94, 0x60, 0xd9, 0x00, 0xd8, 0xbf, 0x2e, 0xd6, 0x92, 0x7e, 0xca, 0x34, 0xd7, 0xb7, 0x84, 0x2b, 0xf8, 0x10, 0xa9, 0x73, 0x08, 0x2d, 0x1e, 0xdc]);

/// Hash prefix used to derive domain name addresses
const String HASH_PREFIX = "SPL Name Service";

/// The `.sol` TLD
/// 58PwtjSDuFHuUkYjH9BYnnQKHfwo9reZhC2zMJv9JPkx
const Ed25519HDPublicKey ROOT_DOMAIN_ACCOUNT = Ed25519HDPublicKey([0x3d, 0x53, 0xc2, 0x4b, 0x38, 0x36, 0x0e, 0xd3, 0x81, 0x3a, 0x23, 0xdf, 0xb2, 0xdf, 0xd8, 0x20, 0xab, 0x58, 0x21, 0xcb, 0x79, 0x29, 0xa3, 0x8d, 0x2e, 0xaa, 0xb2, 0x52, 0xe8, 0x38, 0x25, 0x95]);

class _Derive {
  final Ed25519HDPublicKey pubkey;
  final List<int> hashed;

  _Derive({required this.pubkey, required this.hashed});
}

class DomainKey extends _Derive {
  final bool isSub;
  final Ed25519HDPublicKey? parentKey;

  DomainKey({
    required this.isSub,
    required this.parentKey,
    required Ed25519HDPublicKey pubkey,
    required List<int> hashed,
  }) : super(pubkey: pubkey, hashed: hashed);

  @override
  String toString() {
    return 'DomainKey{isSub: $isSub, parentKey: $parentKey, pubkey: $pubkey, hashed: $hashed}';
  }
}

class DomainResolution {
  final DomainKey domainKey;
  final Ed25519HDPublicKey? owner;

  DomainResolution(this.domainKey, this.owner);
}

Future<List<int>> _getHashedName(String name) async {
  String input = HASH_PREFIX + name;
  Digest str = sha256.convert(input.codeUnits);
  return str.bytes;
}

Future<Ed25519HDPublicKey> _getNameAccountKey(List<int> hashedName, Ed25519HDPublicKey? nameClass, Ed25519HDPublicKey? nameParent) async {
  List<List<int>> seeds = [hashedName];
  if (nameClass != null) {
    seeds.add(nameClass.bytes);
  } else {
    seeds.add(List.generate(32, (index) => 0));
  }
  if (nameParent != null) {
    seeds.add(nameParent.bytes);
  } else {
    seeds.add(List.generate(32, (index) => 0));
  }
  Ed25519HDPublicKey nameAccountKey = await Ed25519HDPublicKey.findProgramAddress(
    seeds: seeds,
    programId: _nameProgramId,
  );
  return nameAccountKey;
}

Future<_Derive> _derive(String name, [Ed25519HDPublicKey? parent]) async {
  // print("Deriving name $name from parent ${parent?.toBase58()}");
  List<int> hashed = await _getHashedName(name);
  // print("Hashed name $hashed");
  Ed25519HDPublicKey pubkey = await _getNameAccountKey(hashed, null, parent ?? _nameProgramId);
  return _Derive(pubkey: pubkey, hashed: hashed);
}

Future<DomainKey> _getDomainKey(String domain) async {
  if (domain.endsWith(".sol")) {
    domain = domain.substring(0, domain.length - 4);
  }
  List<String> splitted = domain.split(".");
  // print("splitted $splitted");
  if (splitted.length == 2) {
    String prefix = "\x00";
    String sub = "$prefix${splitted[0]}";
    Ed25519HDPublicKey parentKey = (await _derive(splitted[1])).pubkey;
    _Derive result = await _derive(sub, parentKey);
    return DomainKey(
      isSub: true,
      parentKey: parentKey,
      pubkey: result.pubkey,
      hashed: result.hashed,
    );
  } else if (splitted.length >= 3) {
    throw "Invalid derivation input";
  }
  _Derive result = await _derive(domain, ROOT_DOMAIN_ACCOUNT);
  // return { ...result, isSub: false, parent: undefined };
  // print("result ${result.pubkey}");
  return DomainKey(
    isSub: false,
    parentKey: null,
    pubkey: result.pubkey,
    hashed: result.hashed,
  );
}

class SnsResolver {
  static Future<DomainResolution> resolve(String domain) async {
    DomainKey domainKey = await _getDomainKey(domain);
    Account? account = await Utils.getAccount(
      domainKey.pubkey.toString(),
      dataSlice: DataSlice(offset: 0x20, length: 0x20),
    );
    if (account != null) {
      BinaryAccountData data = account.data as BinaryAccountData;
      return DomainResolution(domainKey, Ed25519HDPublicKey(data.data));
    } else {
      return DomainResolution(domainKey, null);
    }
  }
}