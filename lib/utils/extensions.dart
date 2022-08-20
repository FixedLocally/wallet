import 'package:flutter/foundation.dart';

extension PubKeys on String {
  String get shortened => "${substring(0, 4)}...${substring(length - 5)}";
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