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
        "activating": MessageLookupByLibrary.simpleMessage("Activating"),
        "active": MessageLookupByLibrary.simpleMessage("Active"),
        "addressCopied": MessageLookupByLibrary.simpleMessage("Address copied"),
        "amount": MessageLookupByLibrary.simpleMessage("Amount"),
        "approveTransactionTitle":
            MessageLookupByLibrary.simpleMessage("Approve transaction?"),
        "areYouSure": MessageLookupByLibrary.simpleMessage("Are you sure?"),
        "bulkTxWarning": MessageLookupByLibrary.simpleMessage(
            "Warning: This website is requesting approval to %s transactions, if you are not performing any bulk operations, please reject this request and contact the website\'s developer."),
        "burn": MessageLookupByLibrary.simpleMessage("Burn and close"),
        "burnConfirm": MessageLookupByLibrary.simpleMessage("Burn %s"),
        "burnConfirmContent": MessageLookupByLibrary.simpleMessage(
            "This action is irreversible, make sure you\'ve selected the correct token."),
        "burningTokens":
            MessageLookupByLibrary.simpleMessage("Burning tokens..."),
        "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
        "chooseToken": MessageLookupByLibrary.simpleMessage("Choose token"),
        "cleanup": MessageLookupByLibrary.simpleMessage("Cleanup"),
        "cleanupTokenAccounts":
            MessageLookupByLibrary.simpleMessage("Cleanup token accounts"),
        "clearConnectionHistory":
            MessageLookupByLibrary.simpleMessage("Clear connection history"),
        "clearConnectionHistoryContent": MessageLookupByLibrary.simpleMessage(
            "You will need to approve all connections to this wallet again."),
        "close": MessageLookupByLibrary.simpleMessage("Close"),
        "closeTokenAccount":
            MessageLookupByLibrary.simpleMessage("Close token account"),
        "closeTokenAccountContent": MessageLookupByLibrary.simpleMessage(
            "Another contract interaction may recreate this account."),
        "connect": MessageLookupByLibrary.simpleMessage("Connect"),
        "connectWallet": MessageLookupByLibrary.simpleMessage("Connect Wallet"),
        "connectWalletContent": MessageLookupByLibrary.simpleMessage(
            "Only connect to websites you trust."),
        "continuE": MessageLookupByLibrary.simpleMessage("Continue"),
        "copy": MessageLookupByLibrary.simpleMessage("Copy"),
        "copyAddress": MessageLookupByLibrary.simpleMessage("Copy address"),
        "copyPrivateKeySuccess": MessageLookupByLibrary.simpleMessage(
            "Copied private key to clipboard"),
        "copySeedSuccess": MessageLookupByLibrary.simpleMessage(
            "Copied secret recovery phrase to clipboard"),
        "createWallet": MessageLookupByLibrary.simpleMessage("Create Wallet"),
        "creatingWallet":
            MessageLookupByLibrary.simpleMessage("Creating wallet..."),
        "deactivating": MessageLookupByLibrary.simpleMessage("Deactivating"),
        "delegationWarning": MessageLookupByLibrary.simpleMessage(
            "%s %s is currently delegated to:\n%s.\n\nUnlike on EVM chains, token delegations beyond the scope of a transaction are typically not needed since most contract interactions atomically transfer the necessary tokens, and will not need access to your funds at a later time.\nPlease consider revoking the delegation."),
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
        "image": MessageLookupByLibrary.simpleMessage("Image"),
        "importWallet": MessageLookupByLibrary.simpleMessage("Import Wallet"),
        "importedWallet":
            MessageLookupByLibrary.simpleMessage("Imported Wallet"),
        "inactive": MessageLookupByLibrary.simpleMessage("Inactive"),
        "insufficientBalance":
            MessageLookupByLibrary.simpleMessage("Insufficient balance"),
        "insufficientFunds":
            MessageLookupByLibrary.simpleMessage("Insufficient funds"),
        "invalidAddress":
            MessageLookupByLibrary.simpleMessage("Invalid address"),
        "invalidAmount": MessageLookupByLibrary.simpleMessage("Invalid amount"),
        "invalidKey": MessageLookupByLibrary.simpleMessage("Invalid key"),
        "invalidKeyContent": MessageLookupByLibrary.simpleMessage(
            "Key must be a base58 encoded string or a JSON array of bytes"),
        "loading": MessageLookupByLibrary.simpleMessage("Loading..."),
        "manageStakeAccounts":
            MessageLookupByLibrary.simpleMessage("Manage stake accounts"),
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
        "noEmptyTokenAccounts": MessageLookupByLibrary.simpleMessage(
            "No empty token accounts found"),
        "ok": MessageLookupByLibrary.simpleMessage("OK"),
        "pay": MessageLookupByLibrary.simpleMessage("Pay"),
        "percentFee": MessageLookupByLibrary.simpleMessage("%s%% fee"),
        "pleaseAuthenticateToContinue": MessageLookupByLibrary.simpleMessage(
            "Please authenticate to continue"),
        "receive": MessageLookupByLibrary.simpleMessage("Receive"),
        "recipient": MessageLookupByLibrary.simpleMessage("Recipient"),
        "redelegate": MessageLookupByLibrary.simpleMessage("Re-delegate"),
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
        "searchValidators":
            MessageLookupByLibrary.simpleMessage("Search Validators"),
        "securitySettings":
            MessageLookupByLibrary.simpleMessage("Security Settings"),
        "seedPhraseWarning": MessageLookupByLibrary.simpleMessage(
            "Your secret recovery phrase is the ONE and ONLY way to access your wallet. DO NOT share it with anyone."),
        "selectAll": MessageLookupByLibrary.simpleMessage("Select all"),
        "send": MessageLookupByLibrary.simpleMessage("Send"),
        "sendToken": MessageLookupByLibrary.simpleMessage("Send %s"),
        "sendingTx":
            MessageLookupByLibrary.simpleMessage("Sending transaction..."),
        "setupWallet": MessageLookupByLibrary.simpleMessage("Setup Wallet"),
        "showPrivateKeyContent": MessageLookupByLibrary.simpleMessage(
            "Do NOT share your private key, having access to your private key means having full access to your funds."),
        "signMessage": MessageLookupByLibrary.simpleMessage("Sign Message"),
        "signMessageHint":
            MessageLookupByLibrary.simpleMessage("Message to sign"),
        "signMessagePrompt":
            MessageLookupByLibrary.simpleMessage("Enter the message to sign:"),
        "signature": MessageLookupByLibrary.simpleMessage("Signature"),
        "signing": MessageLookupByLibrary.simpleMessage("Signing..."),
        "stake": MessageLookupByLibrary.simpleMessage("Stake"),
        "stakeAccount": MessageLookupByLibrary.simpleMessage("Stake Account"),
        "stakeAccounts": MessageLookupByLibrary.simpleMessage("Stake Accounts"),
        "stakeSol": MessageLookupByLibrary.simpleMessage("Stake SOL"),
        "stakeSolSuccessful":
            MessageLookupByLibrary.simpleMessage("Staked %s SOL to %s"),
        "stakeSolToValidator":
            MessageLookupByLibrary.simpleMessage("Stake SOL to Validator"),
        "stakeSolToValidatorConfirm": MessageLookupByLibrary.simpleMessage(
            "You are about to stake %s SOL to %s."),
        "staking": MessageLookupByLibrary.simpleMessage("Staking..."),
        "startUnstaking":
            MessageLookupByLibrary.simpleMessage("Start unstaking"),
        "swap": MessageLookupByLibrary.simpleMessage("Swap"),
        "swapSuccess":
            MessageLookupByLibrary.simpleMessage("Swapped %s %s for %s %s"),
        "tapToReveal": MessageLookupByLibrary.simpleMessage("Hold to reveal"),
        "tokenAccountsClosed":
            MessageLookupByLibrary.simpleMessage("%s Token accounts closed"),
        "transactionMayFailToConfirm": MessageLookupByLibrary.simpleMessage(
            "Transaction may fail to confirm"),
        "txConfirmed":
            MessageLookupByLibrary.simpleMessage("Transaction confirmed"),
        "unstake": MessageLookupByLibrary.simpleMessage("Unstake"),
        "viewOnSolscan":
            MessageLookupByLibrary.simpleMessage("View on SolScan"),
        "visitExternalUrl":
            MessageLookupByLibrary.simpleMessage("Visit External URL"),
        "visitWebsite": MessageLookupByLibrary.simpleMessage("Visit website"),
        "wallet": MessageLookupByLibrary.simpleMessage("Wallet"),
        "walletNum": MessageLookupByLibrary.simpleMessage("Wallet %s"),
        "walletSettings":
            MessageLookupByLibrary.simpleMessage("Wallet Settings"),
        "withdraw": MessageLookupByLibrary.simpleMessage("Withdraw"),
        "yes": MessageLookupByLibrary.simpleMessage("Yes"),
        "yourSecretRecoveryPhraseIs": MessageLookupByLibrary.simpleMessage(
            "Your secret recovery phrase is:")
      };
}
