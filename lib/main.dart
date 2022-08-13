import 'package:flutter/material.dart';
import 'routes/entry_point.dart';

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
    ThemeData darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xff58dcb3),
        onPrimary: Color(0xff101e1b),
        primaryContainer: Color(0xff235847),
        onPrimaryContainer: Color(0xffd8e4e0),
        secondary: Color(0xff61ffd3),
        onSecondary: Color(0xff111e1e),
        secondaryContainer: Color(0xff3a997e),
        onSecondaryContainer: Color(0xffddf4ed),
        tertiary: Color(0xff7effd9),
        onTertiary: Color(0xff141e1e),
        tertiaryContainer: Color(0xff10b383),
        onTertiaryContainer: Color(0xff082e23),
        error: Color(0xffcf6679),
        onError: Color(0xff1e1214),
        errorContainer: Color(0xffb1384e),
        onErrorContainer: Color(0xfff9dde2),
        outline: Color(0xff959999),
        background: Color(0xff151c1a),
        onBackground: Color(0xffe3e4e4),
        surface: Color(0xff121615),
        onSurface: Color(0xfff1f1f1),
        surfaceVariant: Color(0xff141c19),
        onSurfaceVariant: Color(0xffe3e4e3),
        inverseSurface: Color(0xfffafefc),
        onInverseSurface: Color(0xff0e0e0e),
        inversePrimary: Color(0xff336a59),
        shadow: Color(0xff000000),
      ),
      fontFamily: "NotoSans",
      elevatedButtonTheme: elevatedButtonThemeData,
    );
    return MaterialApp(
      title: 'Flutter Demo',
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: const EntryPointRoute(),
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