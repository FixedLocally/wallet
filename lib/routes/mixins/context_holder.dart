import 'package:flutter/widgets.dart';

mixin ContextHolderMixin<T extends StatefulWidget> on State<T> {
  late ContextHolder _contextHolder;

  ContextHolder get contextHolder => _contextHolder;

  @override
  void initState() {
    super.initState();
    _contextHolder = ContextHolder._();
    _contextHolder._context = context;
  }

  @override
  dispose() {
    super.dispose();
    _contextHolder._context = null;
    _contextHolder._disposed = true;
  }
}

class ContextHolder {
  BuildContext? _context;
  bool _disposed = false;

  BuildContext? get context => _context;
  bool get disposed => _disposed;

  ContextHolder._();
}