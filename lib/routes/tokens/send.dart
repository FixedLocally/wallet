import 'package:flutter/material.dart';


class SendTokenRoute extends StatefulWidget {
  const SendTokenRoute({Key? key}) : super(key: key);

  @override
  State<SendTokenRoute> createState() => _SendTokenRouteState();
}

class _SendTokenRouteState extends State<SendTokenRoute> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            ],
          ),
        ),
      ),
    );
  }
}
