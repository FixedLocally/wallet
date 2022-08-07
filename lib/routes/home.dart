import 'package:flutter/material.dart';
import 'package:wallet/routes/webview.dart';
import 'package:wallet/utils/utils.dart';

class HomeRoute extends StatefulWidget {
  const HomeRoute({Key? key}) : super(key: key);

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute> {
  @override
  void initState() {
    Utils.loadAssets();
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
      ),
      body: Column(
        children: [
          _createListTile("Raydium", "https://raydium.io/pools"),
          _createListTile("Zeta Markets", "https://mainnet.zeta.markets/"),
          _createListTile("Jupiter", "https://jup.ag/"),
          _createListTile("Solend", "https://solend.fi/dashboard"),
          _createListTile("Tulip", "https://tulip.garden/lend"),
        ],
      ),
    );
  }

  Widget _createListTile(String title, String url) {
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(title),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => DAppRoute(
            title: title,
            initialUrl: url,
          ),
        ));
      },
    );
  }
}
