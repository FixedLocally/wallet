// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(_current != null,
        'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.');
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(instance != null,
        'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?');
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Receive`
  String get receive {
    return Intl.message(
      'Receive',
      name: 'receive',
      desc: '',
      args: [],
    );
  }

  /// `Amount`
  String get amount {
    return Intl.message(
      'Amount',
      name: 'amount',
      desc: '',
      args: [],
    );
  }

  /// `Pay`
  String get pay {
    return Intl.message(
      'Pay',
      name: 'pay',
      desc: '',
      args: [],
    );
  }

  /// `Mocked %s`
  String get mocked {
    return Intl.message(
      'Mocked %s',
      name: 'mocked',
      desc: '',
      args: [],
    );
  }

  /// `Mock Wallet`
  String get mockWallet {
    return Intl.message(
      'Mock Wallet',
      name: 'mockWallet',
      desc: '',
      args: [],
    );
  }

  /// `Enter wallet address to mock:`
  String get mockWalletPrompt {
    return Intl.message(
      'Enter wallet address to mock:',
      name: 'mockWalletPrompt',
      desc: '',
      args: [],
    );
  }

  /// `Mock wallet address`
  String get mockWalletAddress {
    return Intl.message(
      'Mock wallet address',
      name: 'mockWalletAddress',
      desc: '',
      args: [],
    );
  }

  /// `Exit Mock Wallet`
  String get exitMockWallet {
    return Intl.message(
      'Exit Mock Wallet',
      name: 'exitMockWallet',
      desc: '',
      args: [],
    );
  }

  /// `Signature`
  String get signature {
    return Intl.message(
      'Signature',
      name: 'signature',
      desc: '',
      args: [],
    );
  }

  /// `Signing...`
  String get signing {
    return Intl.message(
      'Signing...',
      name: 'signing',
      desc: '',
      args: [],
    );
  }

  /// `Sign Message`
  String get signMessage {
    return Intl.message(
      'Sign Message',
      name: 'signMessage',
      desc: '',
      args: [],
    );
  }

  /// `Enter the message to sign:`
  String get signMessagePrompt {
    return Intl.message(
      'Enter the message to sign:',
      name: 'signMessagePrompt',
      desc: '',
      args: [],
    );
  }

  /// `Message to sign`
  String get signMessageHint {
    return Intl.message(
      'Message to sign',
      name: 'signMessageHint',
      desc: '',
      args: [],
    );
  }

  /// `Wallet`
  String get wallet {
    return Intl.message(
      'Wallet',
      name: 'wallet',
      desc: '',
      args: [],
    );
  }

  /// `Wallet %s`
  String get walletNum {
    return Intl.message(
      'Wallet %s',
      name: 'walletNum',
      desc: '',
      args: [],
    );
  }

  /// `Remove Wallet`
  String get removeWallet {
    return Intl.message(
      'Remove Wallet',
      name: 'removeWallet',
      desc: '',
      args: [],
    );
  }

  /// `Rename Wallet`
  String get renameWallet {
    return Intl.message(
      'Rename Wallet',
      name: 'renameWallet',
      desc: '',
      args: [],
    );
  }

  /// `Create Wallet`
  String get createWallet {
    return Intl.message(
      'Create Wallet',
      name: 'createWallet',
      desc: '',
      args: [],
    );
  }

  /// `New wallet name`
  String get newWalletName {
    return Intl.message(
      'New wallet name',
      name: 'newWalletName',
      desc: '',
      args: [],
    );
  }

  /// `Close token account`
  String get closeTokenAccount {
    return Intl.message(
      'Close token account',
      name: 'closeTokenAccount',
      desc: '',
      args: [],
    );
  }

  /// `Another contract interaction may recreate this account.`
  String get closeTokenAccountContent {
    return Intl.message(
      'Another contract interaction may recreate this account.',
      name: 'closeTokenAccountContent',
      desc: '',
      args: [],
    );
  }

  /// `Transaction confirmed`
  String get txConfirmed {
    return Intl.message(
      'Transaction confirmed',
      name: 'txConfirmed',
      desc: '',
      args: [],
    );
  }

  /// `OK`
  String get ok {
    return Intl.message(
      'OK',
      name: 'ok',
      desc: '',
      args: [],
    );
  }

  /// `Loading...`
  String get loading {
    return Intl.message(
      'Loading...',
      name: 'loading',
      desc: '',
      args: [],
    );
  }

  /// `No Collectibles`
  String get noCollectibles {
    return Intl.message(
      'No Collectibles',
      name: 'noCollectibles',
      desc: '',
      args: [],
    );
  }

  /// `Renaming wallet...`
  String get renamingWallet {
    return Intl.message(
      'Renaming wallet...',
      name: 'renamingWallet',
      desc: '',
      args: [],
    );
  }

  /// `Enter new key`
  String get enterNewKey {
    return Intl.message(
      'Enter new key',
      name: 'enterNewKey',
      desc: '',
      args: [],
    );
  }

  /// `Invalid key`
  String get invalidKey {
    return Intl.message(
      'Invalid key',
      name: 'invalidKey',
      desc: '',
      args: [],
    );
  }

  /// `Key must be a base58 encoded string or a JSON array of bytes`
  String get invalidKeyContent {
    return Intl.message(
      'Key must be a base58 encoded string or a JSON array of bytes',
      name: 'invalidKeyContent',
      desc: '',
      args: [],
    );
  }

  /// `Import Wallet`
  String get importWallet {
    return Intl.message(
      'Import Wallet',
      name: 'importWallet',
      desc: '',
      args: [],
    );
  }

  /// `Imported Wallet`
  String get importedWallet {
    return Intl.message(
      'Imported Wallet',
      name: 'importedWallet',
      desc: '',
      args: [],
    );
  }

  /// `Export Private Key`
  String get exportPrivateKey {
    return Intl.message(
      'Export Private Key',
      name: 'exportPrivateKey',
      desc: '',
      args: [],
    );
  }

  /// `Export Secret Recovery Phrase`
  String get exportSecretRecoveryPhrase {
    return Intl.message(
      'Export Secret Recovery Phrase',
      name: 'exportSecretRecoveryPhrase',
      desc: '',
      args: [],
    );
  }

  /// `Reset Secret Recovery Phrase`
  String get resetSecretRecoveryPhrase {
    return Intl.message(
      'Reset Secret Recovery Phrase',
      name: 'resetSecretRecoveryPhrase',
      desc: '',
      args: [],
    );
  }

  /// `Copied secret recovery phrase to clipboard`
  String get copySeedSuccess {
    return Intl.message(
      'Copied secret recovery phrase to clipboard',
      name: 'copySeedSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Copied private key to clipboard`
  String get copyPrivateKeySuccess {
    return Intl.message(
      'Copied private key to clipboard',
      name: 'copyPrivateKeySuccess',
      desc: '',
      args: [],
    );
  }

  /// `Do NOT share your private key, having access to your private key means having full access to your funds.`
  String get showPrivateKeyContent {
    return Intl.message(
      'Do NOT share your private key, having access to your private key means having full access to your funds.',
      name: 'showPrivateKeyContent',
      desc: '',
      args: [],
    );
  }

  /// `This will remove the wallet from this list, but you will be able to recover it later with the seed phrase.`
  String get removeHdWalletContent {
    return Intl.message(
      'This will remove the wallet from this list, but you will be able to recover it later with the seed phrase.',
      name: 'removeHdWalletContent',
      desc: '',
      args: [],
    );
  }

  /// `This will remove the wallet from this list, make sure you have a backup of your private key.`
  String get removeKeyWalletContent {
    return Intl.message(
      'This will remove the wallet from this list, make sure you have a backup of your private key.',
      name: 'removeKeyWalletContent',
      desc: '',
      args: [],
    );
  }

  /// `%s %s is currently delegated to:\n%s.\n\nUnlike on EVM chains, token delegations beyond the scope of a transaction are typically not needed since most contract interactions atomically transfer the necessary tokens, and will not need access to your funds at a later time.\nPlease consider revoking the delegation.`
  String get delegationWarning {
    return Intl.message(
      '%s %s is currently delegated to:\n%s.\n\nUnlike on EVM chains, token delegations beyond the scope of a transaction are typically not needed since most contract interactions atomically transfer the necessary tokens, and will not need access to your funds at a later time.\nPlease consider revoking the delegation.',
      name: 'delegationWarning',
      desc: '',
      args: [],
    );
  }

  /// `Setup Wallet`
  String get setupWallet {
    return Intl.message(
      'Setup Wallet',
      name: 'setupWallet',
      desc: '',
      args: [],
    );
  }

  /// `Revoke`
  String get revoke {
    return Intl.message(
      'Revoke',
      name: 'revoke',
      desc: '',
      args: [],
    );
  }

  /// `Message`
  String get message {
    return Intl.message(
      'Message',
      name: 'message',
      desc: '',
      args: [],
    );
  }

  /// `Revoking delegation...`
  String get revokingDelegation {
    return Intl.message(
      'Revoking delegation...',
      name: 'revokingDelegation',
      desc: '',
      args: [],
    );
  }

  /// `Delete`
  String get delete {
    return Intl.message(
      'Delete',
      name: 'delete',
      desc: '',
      args: [],
    );
  }

  /// `Copy`
  String get copy {
    return Intl.message(
      'Copy',
      name: 'copy',
      desc: '',
      args: [],
    );
  }

  /// `Deposit`
  String get deposit {
    return Intl.message(
      'Deposit',
      name: 'deposit',
      desc: '',
      args: [],
    );
  }

  /// `Stake`
  String get stake {
    return Intl.message(
      'Stake',
      name: 'stake',
      desc: '',
      args: [],
    );
  }

  /// `Close`
  String get close {
    return Intl.message(
      'Close',
      name: 'close',
      desc: '',
      args: [],
    );
  }

  /// `Yes`
  String get yes {
    return Intl.message(
      'Yes',
      name: 'yes',
      desc: '',
      args: [],
    );
  }

  /// `No`
  String get no {
    return Intl.message(
      'No',
      name: 'no',
      desc: '',
      args: [],
    );
  }

  /// `Sending transaction...`
  String get sendingTx {
    return Intl.message(
      'Sending transaction...',
      name: 'sendingTx',
      desc: '',
      args: [],
    );
  }

  /// `Error sending transactions`
  String get errorSendingTxs {
    return Intl.message(
      'Error sending transactions',
      name: 'errorSendingTxs',
      desc: '',
      args: [],
    );
  }

  /// `Swap`
  String get swap {
    return Intl.message(
      'Swap',
      name: 'swap',
      desc: '',
      args: [],
    );
  }

  /// `Send`
  String get send {
    return Intl.message(
      'Send',
      name: 'send',
      desc: '',
      args: [],
    );
  }

  /// `Send %s`
  String get sendToken {
    return Intl.message(
      'Send %s',
      name: 'sendToken',
      desc: '',
      args: [],
    );
  }

  /// `Recipient`
  String get recipient {
    return Intl.message(
      'Recipient',
      name: 'recipient',
      desc: '',
      args: [],
    );
  }

  /// `Invalid amount`
  String get invalidAmount {
    return Intl.message(
      'Invalid amount',
      name: 'invalidAmount',
      desc: '',
      args: [],
    );
  }

  /// `Insufficient funds`
  String get insufficientFunds {
    return Intl.message(
      'Insufficient funds',
      name: 'insufficientFunds',
      desc: '',
      args: [],
    );
  }

  /// `Invalid address`
  String get invalidAddress {
    return Intl.message(
      'Invalid address',
      name: 'invalidAddress',
      desc: '',
      args: [],
    );
  }

  /// `Continue`
  String get continuE {
    return Intl.message(
      'Continue',
      name: 'continuE',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure?`
  String get areYouSure {
    return Intl.message(
      'Are you sure?',
      name: 'areYouSure',
      desc: '',
      args: [],
    );
  }

  /// `Burn and close`
  String get burn {
    return Intl.message(
      'Burn and close',
      name: 'burn',
      desc: '',
      args: [],
    );
  }

  /// `Burn %s`
  String get burnConfirm {
    return Intl.message(
      'Burn %s',
      name: 'burnConfirm',
      desc: '',
      args: [],
    );
  }

  /// `This action is irreversible, make sure you've selected the correct token.`
  String get burnConfirmContent {
    return Intl.message(
      'This action is irreversible, make sure you\'ve selected the correct token.',
      name: 'burnConfirmContent',
      desc: '',
      args: [],
    );
  }

  /// `Burning tokens...`
  String get burningTokens {
    return Intl.message(
      'Burning tokens...',
      name: 'burningTokens',
      desc: '',
      args: [],
    );
  }

  /// `Approve transaction?`
  String get approveTransactionTitle {
    return Intl.message(
      'Approve transaction?',
      name: 'approveTransactionTitle',
      desc: '',
      args: [],
    );
  }

  /// `Transaction may fail to confirm`
  String get transactionMayFailToConfirm {
    return Intl.message(
      'Transaction may fail to confirm',
      name: 'transactionMayFailToConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Choose token`
  String get chooseToken {
    return Intl.message(
      'Choose token',
      name: 'chooseToken',
      desc: '',
      args: [],
    );
  }

  /// `Search tokens or paste address`
  String get searchTokensOrPasteAddress {
    return Intl.message(
      'Search tokens or paste address',
      name: 'searchTokensOrPasteAddress',
      desc: '',
      args: [],
    );
  }

  /// `MAX`
  String get maxCap {
    return Intl.message(
      'MAX',
      name: 'maxCap',
      desc: '',
      args: [],
    );
  }

  /// `HALF`
  String get halfCap {
    return Intl.message(
      'HALF',
      name: 'halfCap',
      desc: '',
      args: [],
    );
  }

  /// `Hold to reveal`
  String get tapToReveal {
    return Intl.message(
      'Hold to reveal',
      name: 'tapToReveal',
      desc: '',
      args: [],
    );
  }

  /// `Your secret recovery phrase is:`
  String get yourSecretRecoveryPhraseIs {
    return Intl.message(
      'Your secret recovery phrase is:',
      name: 'yourSecretRecoveryPhraseIs',
      desc: '',
      args: [],
    );
  }

  /// `Your secret recovery phrase is the ONE and ONLY way to access your wallet. DO NOT share it with anyone.`
  String get seedPhraseWarning {
    return Intl.message(
      'Your secret recovery phrase is the ONE and ONLY way to access your wallet. DO NOT share it with anyone.',
      name: 'seedPhraseWarning',
      desc: '',
      args: [],
    );
  }

  /// `Please authenticate to continue`
  String get pleaseAuthenticateToContinue {
    return Intl.message(
      'Please authenticate to continue',
      name: 'pleaseAuthenticateToContinue',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
