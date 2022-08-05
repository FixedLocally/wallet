import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late WebViewController _controller;
  late Random _random;
  String? _injectionJs;

  String _messageHandlerKey = "";

  @override
  void initState() {
    super.initState();
    _random = Random();
    _messageHandlerKey = "${_random.nextInt(1e8.floor()).toString().padLeft(8, '0')}${_random.nextInt(1e8.floor()).toString().padLeft(8, '0')}";
    rootBundle.loadString('assets/inject.js').then((String js) {
      setState(() {
        _injectionJs = js;
      });
    });
  }

  void _runInjection() {
    _controller.runJavascript('$_injectionJs\ncreatePhantom("$_messageHandlerKey")');
    print("message handler key: $_messageHandlerKey");
  }

  @override
  Widget build(BuildContext context) {
    print('messageHandler$_messageHandlerKey');
    return Scaffold(
      appBar: AppBar(title: const Text('Webview')),
      body: _injectionJs != null ? WebView(
        initialUrl: 'about:blank',
        javascriptMode: JavascriptMode.unrestricted,
        javascriptChannels: {
          JavascriptChannel(
            name: 'messageHandler$_messageHandlerKey',
            onMessageReceived: (JavascriptMessage message) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(message.message),
              ));
            }
          ),
        },
        onPageStarted: (String url) {
          print('Page started loading: $url');
          _runInjection();
        },
        onPageFinished: (String url) {
          print('Page finished loading: $url');
        },
        onWebViewCreated: (WebViewController webviewController) {
          _controller = webviewController;
          _loadHtmlFromAssets();
        },
      ) : const CircularProgressIndicator(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.arrow_upward),
        onPressed: () {
          _controller.runJavascript('fromFlutter("From Flutter")');
        },
      ),
    );
  }

  _loadHtmlFromAssets() async {
    String file = await rootBundle.loadString('assets/index.html');
    _controller.loadUrl(Uri.dataFromString(
        file,
        mimeType: 'text/html',
        encoding: Encoding.getByName('utf-8')).toString());
  }
}