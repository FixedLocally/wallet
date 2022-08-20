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
        "_locale": MessageLookupByLibrary.simpleMessage("en"),
        "amount": MessageLookupByLibrary.simpleMessage("Amount"),
        "enterTheMessageToSign":
            MessageLookupByLibrary.simpleMessage("Enter the message to sign:"),
        "enterWalletAddressToMock": MessageLookupByLibrary.simpleMessage(
            "Enter wallet address to mock:"),
        "exitMockWallet":
            MessageLookupByLibrary.simpleMessage("Exit Mock Wallet"),
        "messageToSign":
            MessageLookupByLibrary.simpleMessage("Message to sign"),
        "mockWallet": MessageLookupByLibrary.simpleMessage("Mock Wallet"),
        "mockWalletAddress":
            MessageLookupByLibrary.simpleMessage("Mock wallet address"),
        "ok": MessageLookupByLibrary.simpleMessage("OK"),
        "pay": MessageLookupByLibrary.simpleMessage("Pay"),
        "receive": MessageLookupByLibrary.simpleMessage("Receive"),
        "removeWallet": MessageLookupByLibrary.simpleMessage("Remove Wallet"),
        "signMessage": MessageLookupByLibrary.simpleMessage("Sign Message"),
        "signature": MessageLookupByLibrary.simpleMessage("Signature"),
        "signing": MessageLookupByLibrary.simpleMessage("Signing..."),
        "wallet": MessageLookupByLibrary.simpleMessage("Wallet")
      };
}
