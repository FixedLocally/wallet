import 'dart:async';

import 'package:flutter/widgets.dart';

mixin TimerMixin<T extends StatefulWidget> on State<T> {
  int get frequency;

  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: frequency), (_) => onTimer());
  }

  void onTimer();

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }
}