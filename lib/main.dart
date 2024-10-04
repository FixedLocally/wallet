import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'generated/l10n.dart';
import 'routes/entry_point.dart';
import 'routes/observer.dart';
import 'routes/root.dart';

final RouteObserver<ModalRoute> routeObserver = MyRouteObserver();

void main() {
  runApp(const WalletApp());
}

class WalletApp extends StatelessWidget {
  const WalletApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    ElevatedButtonThemeData elevatedButtonThemeData = ElevatedButtonThemeData(
      style: ButtonStyle(
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
        ),
      ),
    );
    TextButtonThemeData textButtonThemeData = TextButtonThemeData(
      style: ButtonStyle(
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
        ),
      ),
    );
    ThemeData darkTheme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Color(0xff292e2c),
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xff57fdc1),
        onPrimary: Color(0xff101e1c),
        primaryContainer: Color(0xff22654d),
        onPrimaryContainer: Color(0xffd8e7e2),
        secondary: Color(0xff1dc5c0),
        onSecondary: Color(0xff101e1e),
        secondaryContainer: Color(0xff235866),
        onSecondaryContainer: Color(0xffd8e4e8),
        tertiary: Color(0xff7dffe7),
        onTertiary: Color(0xff141e1e),
        tertiaryContainer: Color(0xff10b394),
        onTertiaryContainer: Color(0xff082e27),
        error: Color(0xffcf6679),
        onError: Color(0xff1e1214),
        errorContainer: Color(0xffb1384e),
        onErrorContainer: Color(0xfff9dde2),
        outline: Color(0xff959999),
        background: Color(0xff151e1b),
        onBackground: Color(0xffe3e4e4),
        surface: Color(0xff121715),
        onSurface: Color(0xfff1f1f1),
        surfaceVariant: Color(0xff141d1a),
        onSurfaceVariant: Color(0xffe3e4e4),
        inverseSurface: Color(0xfffafefd),
        onInverseSurface: Color(0xff0e0e0e),
        inversePrimary: Color(0xff32735f),
        shadow: Color(0xff000000),
      ),
      fontFamily: "NotoSans",
      elevatedButtonTheme: elevatedButtonThemeData,
      textButtonTheme: textButtonThemeData,
    );
    return WalletAppWidget(
      child: MaterialApp(
        title: 'Mint Wallet',
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        localizationsDelegates: const [
          S.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: const EntryPointRoute(),
        navigatorObservers: [routeObserver],
      ),
    );
  }
}

MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}