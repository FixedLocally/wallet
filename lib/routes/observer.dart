import 'package:flutter/widgets.dart';

class MyRouteObserver extends RouteObserver<ModalRoute> {

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint("pop ${route.settings.name} => ${previousRoute?.settings.name}");
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint("push ${previousRoute?.settings.name} => ${route.settings.name}");
  }
}