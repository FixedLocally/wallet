import 'package:flutter/foundation.dart';

extension PubKeys on String {
  String get shortened => "${substring(0, 4)}...${substring(length - 5)}";
  void printBySegment(int len) {
    for (int i = 0; i < length; i += len) {
      print(substring(i, (i + len).clamp(0, length)));
    }
  }
}

extension IterableExtenstion<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension NullableIterableExtenstion<T> on Iterable<T?> {
  Iterable<T> get whereNotNull => where((e) => e != null).map((e) => e!);
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