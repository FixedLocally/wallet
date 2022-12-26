import 'package:flutter/widgets.dart';

class MyRouteObserver extends RouteObserver<ModalRoute> {

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print("pop ${route.settings.name} => ${previousRoute?.settings.name}");
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print("push ${previousRoute?.settings.name} => ${route.settings.name}");
  }
}