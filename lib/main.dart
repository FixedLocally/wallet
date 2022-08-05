import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wallet/rpc.dart';
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
  WebViewController? _controller;
  String? _title;
  late Random _random;

  String _injectionJs = "";
  String _realMessageHandlerKey = "";

  Set<JavascriptChannel> get _jsChannels => {
    JavascriptChannel(
        name: 'messageHandler$_realMessageHandlerKey',
        onMessageReceived: (JavascriptMessage message) {
          String msg = message.message;
          print('messageHandler: $msg');
          Map call = jsonDecode(msg);
          String method = call['method'];
          Map args = call['args'] ?? {};
          int id = call['id'];
          Rpc.entryPoint(context, method, args).then((value) {
            if (value.isError) {
              _rpcReject(value.response, id);
            } else {
              _rpcResolve(value.response, id);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
          ));
        }
    ),
    ..._bogusMessageHandlerKeys.map((key) => JavascriptChannel(
        name: 'messageHandler$key',
        onMessageReceived: (JavascriptMessage message) {
          // does nothing.
        }
    )),
  };

  final List<String> _bogusMessageHandlerKeys = [];

  @override
  void initState() {
    super.initState();
    _random = Random();
    _realMessageHandlerKey = _createKey();
    rootBundle.loadString('assets/inject.js').then((String js) {
      setState(() {
        _injectionJs = js;
      });
    });
    for (int i = 0; i < 99; ++i) {
      _bogusMessageHandlerKeys.add(_createKey());
    }
  }

  String _createKey() {
    return "${_random.nextInt(1e8.floor()).toString().padLeft(8, '0')}${_random.nextInt(1e8.floor()).toString().padLeft(8, '0')}";
  }

  Future _runInjection() async {
    String js = '($_injectionJs)("$_realMessageHandlerKey", ${jsonEncode(_bogusMessageHandlerKeys)})';
    await _controller!.runJavascript(js);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title ?? 'WebView')),
      body: _injectionJs.isNotEmpty ? _webView() : const CircularProgressIndicator(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.arrow_upward),
        onPressed: () {
          _controller!.runJavascript('fromFlutter("From Flutter")');
        },
      ),
    );
  }

  _loadHtmlFromAssets() async {
    return _controller!.loadFlutterAsset('assets/index.html');
  }

  Widget _webView() {
    return WebView(
      initialUrl: 'https://r3byv.csb.app/',
      // initialUrl: 'about:blank',
      // initialUrl: 'https://tulip.garden/',
      javascriptMode: JavascriptMode.unrestricted,
      javascriptChannels: _jsChannels,
      onPageStarted: (String url) {
        setState(() {
          _title = url;
        });
      },
      onWebViewCreated: (WebViewController webviewController) {
        _controller = webviewController;
        // _loadHtmlFromAssets();
      },
      onPageFinished: (String url) async {
        _runInjection();
        _controller?.getTitle().then((title) {
          setState(() {
            _title = title.toString();
          });
        });
      },
    );
  }

  void _rpcResolve(dynamic response, int id) {
    String msg = jsonEncode(response);
    _controller!.runJavascript('window["resolveRpc$_realMessageHandlerKey"]($id, $msg)');
  }

  void _rpcReject(dynamic response, int id) {
    String msg = jsonEncode(response);
    _controller!.runJavascript('window["rejectRpc$_realMessageHandlerKey"]($id, $msg)');
  }
}