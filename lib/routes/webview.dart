import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wallet/utils/utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../context_holder.dart';
import '../rpc/rpc.dart';

class DAppRoute extends StatefulWidget {
  const DAppRoute({
    Key? key,
    required this.title,
    required this.initialUrl,
  }) : super(key: key);

  final String title;
  final String initialUrl;

  @override
  State<DAppRoute> createState() => _DAppRouteState();
}

class _DAppRouteState extends State<DAppRoute> with ContextHolderMixin<DAppRoute> {
  WebViewController? _controller;
  String? _title;
  String? _subtitle;
  late Random _random;
  late StreamSubscription<RpcEvent> _sub;

  String _realMessageHandlerKey = "";
  bool _injected = false;
  bool _ready = false;

  Set<JavascriptChannel> get _jsChannels => {
    JavascriptChannel(
      name: 'messageHandler$_realMessageHandlerKey',
      onMessageReceived: (JavascriptMessage message) {
        String msg = message.message;
        Map call = jsonDecode(msg);
        String method = call['method'];
        Map params = call['params'] ?? {};
        int id = call['id'];
        RpcServer.entryPoint(contextHolder, method, params).then((value) {
          print("rpcCall: $method, $params => $value");
          if (value.isError) {
            _rpcReject(value.response, id);
          } else {
            _rpcResolve(value.response, id);
          }
        });
        // String snackBarContent = msg.length > 200 ? "${msg.substring(0, 200)}..." : msg;
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        //   content: Text(snackBarContent),
        // ));
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
    if (Platform.isAndroid) WebView.platform = AndroidWebView();
    Utils.loadAssets().then((value) {
      setState(() {
        _ready = true;
      });
    });
    for (int i = 0; i < 99; ++i) {
      _bogusMessageHandlerKeys.add(_createKey());
    }
    _sub = RpcServer.eventStream.listen((event) async {
      print("rpcEvent: $event");
      await _controller?.runJavascript("window.eventIngestion$_realMessageHandlerKey('${event.trigger}', ${jsonEncode(event.response)}, ${jsonEncode(event.updates)})");
    });
  }

  String _createKey() {
    return "${_random.nextInt(1e8.floor()).toString().padLeft(8, '0')}${_random.nextInt(1e8.floor()).toString().padLeft(8, '0')}";
  }

  Future _runInjection() async {
    String js = '(${Utils.injectionJs})("$_realMessageHandlerKey", ${jsonEncode(_bogusMessageHandlerKeys)})';
    Future f2 = _controller!.runJavascript(Utils.web3Js);
    await f2;
    Future f1 = _controller!.runJavascript(js);
    await f1;
    _injected = true;
    // return Future.wait([f1, f2]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(_title ?? 'WebView'),
            if (_subtitle != null)
              Text(
                _subtitle!,
                style: const TextStyle(fontSize: 14),
              ),
          ],
        ),
        centerTitle: true,
      ),
      body: _ready ? _webView() : const CircularProgressIndicator(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.refresh),
        onPressed: () {
          // _controller!.runJavascript('document.write(phantom.solana.publicKey)');
          _controller!.reload();
          _injected = false;
        },
      ),
    );
  }

  Widget _webView() {
    return WebView(
      // initialUrl: 'https://r3byv.csb.app/',
      // initialUrl: 'about:blank',
      // initialUrl: 'https://tulip.garden/',
      // initialUrl: 'https://mainnet.zeta.markets/',
      // initialUrl: 'https://solend.fi/dashboard',
      // initialUrl: 'http://localhost:3000/',
      initialUrl: widget.initialUrl,
      javascriptMode: JavascriptMode.unrestricted,
      javascriptChannels: _jsChannels,

      onPageStarted: (String url) {
        setState(() {
          _title = "Loading...";
        });
      },
      onWebViewCreated: (WebViewController webviewController) {
        _controller = webviewController;
        // _loadHtmlFromAssets();
      },
      onPageFinished: (String url) async {
        if (_injected) return;
        _runInjection();
        _controller?.getTitle().then((title) {
          if (title != null) {
            setState(() {
              _subtitle = url;
              _title = title;
            });
          }
        });
      },
      navigationDelegate: (NavigationRequest request) async {
        String currentUrl = await _controller!.currentUrl() ?? "";
        if (request.url.split("#").first != currentUrl.split("#").first) {
          // page changed
          await RpcServer.entryPoint(contextHolder, "disconnect", {});
          setState(() {
            _title = request.url;
            _subtitle = null;
            _injected = false;
          });
        }
        return NavigationDecision.navigate;
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

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}