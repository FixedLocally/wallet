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
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: "NotoSans",
        elevatedButtonTheme: elevatedButtonThemeData,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: "NotoSans",
        elevatedButtonTheme: elevatedButtonThemeData,
      ),
      home: const EntryPointRoute(),
    );
  }
}
