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
        "approveTransactionTitle":
            MessageLookupByLibrary.simpleMessage("Approve transaction?"),
        "areYouSure": MessageLookupByLibrary.simpleMessage("Are you sure?"),
        "burn": MessageLookupByLibrary.simpleMessage("Burn and close"),
        "burnConfirm": MessageLookupByLibrary.simpleMessage("Burn %s"),
        "burnConfirmContent": MessageLookupByLibrary.simpleMessage(
            "This action is irreversible, make sure you\'ve selected the correct token."),
        "burningTokens":
            MessageLookupByLibrary.simpleMessage("Burning tokens..."),
        "chooseToken": MessageLookupByLibrary.simpleMessage("Choose token"),
        "close": MessageLookupByLibrary.simpleMessage("Close"),
        "closeTokenAccount":
            MessageLookupByLibrary.simpleMessage("Close token account"),
        "closeTokenAccountContent": MessageLookupByLibrary.simpleMessage(
            "Another contract interaction may recreate this account."),
        "continuE": MessageLookupByLibrary.simpleMessage("Continue"),
        "copy": MessageLookupByLibrary.simpleMessage("Copy"),
        "copyPrivateKeySuccess": MessageLookupByLibrary.simpleMessage(
            "Copied private key to clipboard"),
        "copySeedSuccess": MessageLookupByLibrary.simpleMessage(
            "Copied secret recovery phrase to clipboard"),
        "createWallet": MessageLookupByLibrary.simpleMessage("Create Wallet"),
        "delegationWarning": MessageLookupByLibrary.simpleMessage(
            "%s %s is currently delegated to:\n%s.\n\nUnlike on Ethereum, token delegations beyond the scope of a transaction are typically not needed since most contract interactions atomically transfer the necessary tokens, and will not need access to your funds at a later time.\nPlease consider revoking the delegation."),
        "delete": MessageLookupByLibrary.simpleMessage("Delete"),
        "deposit": MessageLookupByLibrary.simpleMessage("Deposit"),
        "enterNewKey": MessageLookupByLibrary.simpleMessage("Enter new key"),
        "errorSendingTxs":
            MessageLookupByLibrary.simpleMessage("Error sending transactions"),
        "exitMockWallet":
            MessageLookupByLibrary.simpleMessage("Exit Mock Wallet"),
        "exportPrivateKey":
            MessageLookupByLibrary.simpleMessage("Export Private Key"),
        "exportSecretRecoveryPhrase": MessageLookupByLibrary.simpleMessage(
            "Export Secret Recovery Phrase"),
        "halfCap": MessageLookupByLibrary.simpleMessage("HALF"),
        "importWallet": MessageLookupByLibrary.simpleMessage("Import Wallet"),
        "importedWallet":
            MessageLookupByLibrary.simpleMessage("Imported Wallet"),
        "insufficientFunds":
            MessageLookupByLibrary.simpleMessage("Insufficient funds"),
        "invalidAddress":
            MessageLookupByLibrary.simpleMessage("Invalid address"),
        "invalidAmount": MessageLookupByLibrary.simpleMessage("Invalid amount"),
        "invalidKey": MessageLookupByLibrary.simpleMessage("Invalid key"),
        "invalidKeyContent": MessageLookupByLibrary.simpleMessage(
            "Key must be a base58 encoded string or a JSON array of bytes"),
        "loading": MessageLookupByLibrary.simpleMessage("Loading..."),
        "maxCap": MessageLookupByLibrary.simpleMessage("MAX"),
        "message": MessageLookupByLibrary.simpleMessage("Message"),
        "mockWallet": MessageLookupByLibrary.simpleMessage("Mock Wallet"),
        "mockWalletAddress":
            MessageLookupByLibrary.simpleMessage("Mock wallet address"),
        "mockWalletPrompt": MessageLookupByLibrary.simpleMessage(
            "Enter wallet address to mock:"),
        "mocked": MessageLookupByLibrary.simpleMessage("Mocked %s"),
        "newWalletName":
            MessageLookupByLibrary.simpleMessage("New wallet name"),
        "no": MessageLookupByLibrary.simpleMessage("No"),
        "noCollectibles":
            MessageLookupByLibrary.simpleMessage("No Collectibles"),
        "ok": MessageLookupByLibrary.simpleMessage("OK"),
        "pay": MessageLookupByLibrary.simpleMessage("Pay"),
        "receive": MessageLookupByLibrary.simpleMessage("Receive"),
        "recipient": MessageLookupByLibrary.simpleMessage("Recipient"),
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
        "revoke": MessageLookupByLibrary.simpleMessage("Revoke"),
        "revokingDelegation":
            MessageLookupByLibrary.simpleMessage("Revoking delegation..."),
        "searchTokensOrPasteAddress": MessageLookupByLibrary.simpleMessage(
            "Search tokens or paste address"),
        "send": MessageLookupByLibrary.simpleMessage("Send"),
        "sendToken": MessageLookupByLibrary.simpleMessage("Send %s"),
        "sendingTx":
            MessageLookupByLibrary.simpleMessage("Sending transaction..."),
        "setupWallet": MessageLookupByLibrary.simpleMessage("Setup Wallet"),
        "showPrivateKeyContent": MessageLookupByLibrary.simpleMessage(
            "Do NOT share your private key, having access to your private means having access to your funds."),
        "signMessage": MessageLookupByLibrary.simpleMessage("Sign Message"),
        "signMessageHint":
            MessageLookupByLibrary.simpleMessage("Message to sign"),
        "signMessagePrompt":
            MessageLookupByLibrary.simpleMessage("Enter the message to sign:"),
        "signature": MessageLookupByLibrary.simpleMessage("Signature"),
        "signing": MessageLookupByLibrary.simpleMessage("Signing..."),
        "stake": MessageLookupByLibrary.simpleMessage("Stake"),
        "swap": MessageLookupByLibrary.simpleMessage("Swap"),
        "tapToReveal": MessageLookupByLibrary.simpleMessage("Hold to reveal"),
        "transactionMayFailToConfirm": MessageLookupByLibrary.simpleMessage(
            "Transaction may fail to confirm"),
        "txConfirmed":
            MessageLookupByLibrary.simpleMessage("Transaction confirmed"),
        "wallet": MessageLookupByLibrary.simpleMessage("Wallet"),
        "walletNum": MessageLookupByLibrary.simpleMessage("Wallet %s"),
        "yes": MessageLookupByLibrary.simpleMessage("Yes")
      };
}
