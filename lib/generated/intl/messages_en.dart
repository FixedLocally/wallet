// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "amount": MessageLookupByLibrary.simpleMessage("Amount"),
        "close": MessageLookupByLibrary.simpleMessage("Close"),
        "closeAccount": MessageLookupByLibrary.simpleMessage("Close account"),
        "closeTokenAccount":
            MessageLookupByLibrary.simpleMessage("Close token account"),
        "closeTokenAccountContent": MessageLookupByLibrary.simpleMessage(
            "Another contract interaction may recreate this account."),
        "copy": MessageLookupByLibrary.simpleMessage("Copy"),
        "copyPrivateKeySuccess": MessageLookupByLibrary.simpleMessage(
            "Copied private key to clipboard"),
        "copySeedSuccess": MessageLookupByLibrary.simpleMessage(
            "Copied secret recovery phrase to clipboard"),
        "createWallet": MessageLookupByLibrary.simpleMessage("Create Wallet"),
        "delete": MessageLookupByLibrary.simpleMessage("Delete"),
        "deposit": MessageLookupByLibrary.simpleMessage("Deposit"),
        "enterNewKey": MessageLookupByLibrary.simpleMessage("Enter new key"),
        "enterTheMessageToSign":
            MessageLookupByLibrary.simpleMessage("Enter the message to sign:"),
        "enterWalletAddressToMock": MessageLookupByLibrary.simpleMessage(
            "Enter wallet address to mock:"),
        "exitMockWallet":
            MessageLookupByLibrary.simpleMessage("Exit Mock Wallet"),
        "exportPrivateKey":
            MessageLookupByLibrary.simpleMessage("Export Private Key"),
        "exportSecretRecoveryPhrase": MessageLookupByLibrary.simpleMessage(
            "Export Secret Recovery Phrase"),
        "importWallet": MessageLookupByLibrary.simpleMessage("Import Wallet"),
        "importedWallet":
            MessageLookupByLibrary.simpleMessage("Imported Wallet"),
        "invalidKey": MessageLookupByLibrary.simpleMessage("Invalid key"),
        "invalidKeyContent": MessageLookupByLibrary.simpleMessage(
            "Key must be a base58 encoded string or a JSON array of bytes"),
        "loading": MessageLookupByLibrary.simpleMessage("Loading..."),
        "messageToSign":
            MessageLookupByLibrary.simpleMessage("Message to sign"),
        "mockWallet": MessageLookupByLibrary.simpleMessage("Mock Wallet"),
        "mockWalletAddress":
            MessageLookupByLibrary.simpleMessage("Mock wallet address"),
        "mocked": MessageLookupByLibrary.simpleMessage("Mocked"),
        "newWalletName":
            MessageLookupByLibrary.simpleMessage("New wallet name"),
        "noCollectibles":
            MessageLookupByLibrary.simpleMessage("No Collectibles"),
        "ok": MessageLookupByLibrary.simpleMessage("OK"),
        "pay": MessageLookupByLibrary.simpleMessage("Pay"),
        "receive": MessageLookupByLibrary.simpleMessage("Receive"),
        "removeHdWalletContent": MessageLookupByLibrary.simpleMessage(
            "This will remove the wallet from this list, but you will be able to recover it later with the seed phrase."),
        "removeKeyWalletContent": MessageLookupByLibrary.simpleMessage(
            "This will remove the wallet from this list, make sure you have a backup of your private key."),
        "removeWallet": MessageLookupByLibrary.simpleMessage("Remove Wallet"),
        "renameWallet": MessageLookupByLibrary.simpleMessage("Rename Wallet"),
        "renamingWallet":
            MessageLookupByLibrary.simpleMessage("Renaming wallet..."),
        "resetSecretRecoveryPhrase": MessageLookupByLibrary.simpleMessage(
            "Reset Secret Recovery Phrase"),
        "showPrivateKeyContent": MessageLookupByLibrary.simpleMessage(
            "Private key:\n%s\n\nDo NOT share your private key, having access to your private means having access to your funds."),
        "signMessage": MessageLookupByLibrary.simpleMessage("Sign Message"),
        "signature": MessageLookupByLibrary.simpleMessage("Signature"),
        "signing": MessageLookupByLibrary.simpleMessage("Signing..."),
        "stake": MessageLookupByLibrary.simpleMessage("Stake"),
        "txConfirmed":
            MessageLookupByLibrary.simpleMessage("Transaction confirmed"),
        "wallet": MessageLookupByLibrary.simpleMessage("Wallet")
      };
}
