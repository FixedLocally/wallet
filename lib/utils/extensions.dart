import 'package:flutter/foundation.dart';

extension StrExt on String {
  String get shortened => "${substring(0, 4)}...${substring(length - 4)}";
  double get doubleParsed => double.parse(this);
  int get intParsed => int.parse(this);
  void printBySegment(int len) {
    for (int i = 0; i < length; i += len) {
      debugPrint(substring(i, (i + len).clamp(0, length)));
    }
  }
}

extension NumExt on num {
  String toFixedTrimmed(int? fractionDigits) {
    if (fractionDigits == null) {
      fractionDigits = 6;
      num _this = this;
      while (_this < 1) {
        _this *= 1000;
        fractionDigits = fractionDigits! + 3;
      }
    }
    return double.parse(toStringAsFixed(fractionDigits!)).toString();
  }
}

extension IterableExtenstion<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension NullableIterableExtenstion<T> on Iterable<T?> {
  Iterable<T> get whereNotNull => where((e) => e != null).map((e) => e!);
}

extension ListExtension<T> on List<T> {
  List<T2> mapIndexed<T2>(T2 Function(int, T) callback) => asMap().map((k, v) => MapEntry(k, callback(k, v))).values.toList();
}

extension Debouncable<T> on ValueNotifier<T> {
  void debounce(Duration duration, ValueChanged<T> callback) {
    addListener(() {
      Future debounce = Future.delayed(duration);
      T previousValue = value;
      debounce.then((_) {
        if (value == previousValue) {
          callback(value);
        }
      });
    });
  }
}

extension Decimals on BigInt {
  String addDecimals(int decimals) {
    String str = toString();
    if (str.length <= decimals) {
      str = "0.${"0" * (decimals - str.length)}$str";
    } else {
      str = "${str.substring(0, str.length - decimals)}.${str.substring(str.length - decimals)}";
    }
    return str.replaceAll(RegExp(r"\.?0+$"), "");
  }
}