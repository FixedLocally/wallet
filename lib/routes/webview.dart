import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../generated/l10n.dart';
import 'mixins/timer.dart';
import '../utils/utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'mixins/context_holder.dart';
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

class _DAppRouteState extends State<DAppRoute> with ContextHolderMixin<DAppRoute>, TimerMixin<DAppRoute> {
  WebViewController? _controller;
  String? _title;
  String? _subtitle;
  late Random _random;
  late StreamSubscription<RpcEvent> _sub;

  late Completer _injectionCompleter;

  String _realMessageHandlerKey = "";
  bool _ready = false;
  bool _exit = false;

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

  @override
  int get frequency => 1000;

  final List<String> _bogusMessageHandlerKeys = [];

  @override
  void initState() {
    super.initState();
    _random = Random();
    _realMessageHandlerKey = _createKey();
    if (Platform.isAndroid) WebView.platform = AndroidWebView();
    _ready = true;
    for (int i = 0; i < 99; ++i) {
      _bogusMessageHandlerKeys.add(_createKey());
    }
    _sub = RpcServer.eventStream.listen((event) async {
      print("rpcEvent: $event");
      await _controller?.runJavascript("window.eventIngestion$_realMessageHandlerKey('${event.trigger}', ${jsonEncode(event.response)}, ${jsonEncode(event.updates)})");
    });
  }

  @override
  void onTimer() {
    _controller?.getTitle().then((value) {
      if (value != _title) {
        setState(() {
          _title = value;
        });
      }
    });
  }

  String _createKey() {
    return "${_random.nextInt(1e8.floor()).toString().padLeft(8, '0')}${_random.nextInt(1e8.floor()).toString().padLeft(8, '0')}";
  }

  Future _runInjection() async {
    Completer completer = Completer();
    _injectionCompleter = completer;
    String js = '(${Utils.injectionJs})("$_realMessageHandlerKey", ${jsonEncode(_bogusMessageHandlerKeys)})';
    Future f1 = _controller!.runJavascript(js);
    await f1;
    completer.complete();
  }

  @override
  Widget build(BuildContext context) {
    Widget scaffold = Scaffold(
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            _exit = true;
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller?.reload();
            },
          ),
        ],
      ),
      body: _ready ? _webView() : const CircularProgressIndicator(),
    );

    return WillPopScope(
      onWillPop: () async {
        if (await _controller?.canGoBack() == true && !_exit) {
          _controller?.goBack();
          return false;
        }
        return true;
      },
      child: scaffold,
    );
  }

  Widget _webView() {
    return WebView(
      // initialUrl: 'https://r3byv.csb.app/',
      initialUrl: widget.initialUrl,
      // initialUrl: 'https://tulip.garden/',
      // initialUrl: 'https://mainnet.zeta.markets/',
      // initialUrl: 'https://solend.fi/dashboard',
      // initialUrl: 'http://localhost:3000/',
      // initialUrl: widget.initialUrl,
      javascriptMode: JavascriptMode.unrestricted,
      javascriptChannels: _jsChannels,
      debuggingEnabled: kDebugMode,

      onPageStarted: (String url) {
        _runInjection();
        setState(() {
          _title = S.current.loading;
          _subtitle = url;
        });
      },
      onWebViewCreated: (WebViewController webviewController) {
        _controller = webviewController;
        // _loadHtmlFromAssets();
      },
      onPageFinished: (String url) async {
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
          if (RpcServer.connected) {
            await RpcServer.entryPoint(contextHolder, "disconnect", {});
          }
          setState(() {
            _title = request.url;
            _subtitle = null;
          });
        }
        return NavigationDecision.navigate;
      },
    );
  }

  void _rpcResolve(dynamic response, int id) {
    String msg = jsonEncode(response);
    print('window["resolveRpc$_realMessageHandlerKey"]($id, $msg)');
    _injectionCompleter.future.then((value) => _controller!.runJavascript('window["resolveRpc$_realMessageHandlerKey"]($id, $msg)'));
  }

  void _rpcReject(dynamic response, int id) {
    String msg = jsonEncode(response);
    _injectionCompleter.future.then((value) => _controller!.runJavascript('window["rejectRpc$_realMessageHandlerKey"]($id, $msg)'));
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}