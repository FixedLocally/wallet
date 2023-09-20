import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../generated/l10n.dart';
import 'mixins/timer.dart';
import '../utils/utils.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

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
  String? _title;
  String? _subtitle;
  late WebViewController _controller;
  late Random _random;
  late StreamSubscription<RpcEvent> _sub;

  late Completer _injectionCompleter;

  String _realMessageHandlerKey = "";
  bool _ready = false;
  bool _exit = false;

  Set<JavaScriptChannel> get _jsChannels => {
    JavaScriptChannel(
      name: 'messageHandler$_realMessageHandlerKey',
      onMessageReceived: (JavaScriptMessage message) async {
        String msg = message.message;
        Map call = jsonDecode(msg);
        String method = call['method'];
        Map params = call['params'] ?? {};
        int id = call['id'];
        String url = await _controller.currentUrl() ?? "";
        params['domain'] = Uri.parse(url).host;
        RpcServer.entryPoint(contextHolder, method, params).then((value) {
          debugPrint("rpcCall: $method, $params => $value");
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
    ..._bogusMessageHandlerKeys.map((key) => JavaScriptChannel(
        name: 'messageHandler$key',
        onMessageReceived: (JavaScriptMessage message) {
          // does nothing.
        }
    )),
  };

  @override
  int get frequency => 1000;

  final List<String> _bogusMessageHandlerKeys = [];

  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _random = Random();
    _realMessageHandlerKey = _createKey();
    _ready = true;
    for (int i = 0; i < 99; ++i) {
      _bogusMessageHandlerKeys.add(_createKey());
    }

    // create webview controller and enable js
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    // enable debugging if necessary
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(!kReleaseMode);
    }
    // initialUrl
    _controller.loadRequest(Uri.parse(widget.initialUrl));
    _controller.setNavigationDelegate(NavigationDelegate(
      onPageStarted: (String url) {
        _runInjection();
        setState(() {
          _title = S.current.loading;
          _subtitle = url;
        });
      },
      onPageFinished: (String url) async {
        _runInjection();
        _controller.getTitle().then((title) {
          if (title != null) {
            setState(() {
              _subtitle = url;
              _title = title;
            });
          }
        });
      },
      onProgress: (int progress) {
        debugPrint("onProgress: $progress");
        setState(() {
          _progress = progress;
        });
        if (progress == 100) {
          // hide progress bar after 500ms
          Future.delayed(const Duration(milliseconds: 500), () {
            setState(() {
              _progress = 0;
            });
          });
        }
      },
      onUrlChange: (UrlChange request) async {
        setState(() {
          _subtitle = request.url;
        });
        // return NavigationDecision.navigate;
      },
      onNavigationRequest: (NavigationRequest request) async {
        debugPrint("onNavigationRequest: ${request.url}");
        // page changed
        if (RpcServer.connected) {
          await RpcServer.entryPoint(contextHolder, "disconnect", {});
        }
        setState(() {
          _title = request.url;
          _subtitle = null;
        });
        return NavigationDecision.navigate;
      },
      onWebResourceError: (WebResourceError error) {
        debugPrint("onWebResourceError: ${error.errorType}");
      },
    ));

    for (JavaScriptChannel c in _jsChannels) {
      _controller.addJavaScriptChannel(c.name, onMessageReceived: c.onMessageReceived);
    }
    _sub = RpcServer.eventStream.listen((event) async {
      debugPrint("rpcEvent: $event");
      await _controller.runJavaScript("window.eventIngestion$_realMessageHandlerKey('${event.trigger}', ${jsonEncode(event.response)}, ${jsonEncode(event.updates)})");
    });
  }

  @override
  void onTimer() {
    _controller.getTitle().then((value) {
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
    String js = '${Utils.injectionJs}("$_realMessageHandlerKey", ${jsonEncode(_bogusMessageHandlerKeys)})';
    Future f1 = _controller.runJavaScript(js);
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _progress > 0 ? LinearProgressIndicator(
            value: _progress / 100,
            backgroundColor: Colors.white,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.secondary),
          ) : SizedBox(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
          ),
        ],
      ),
      body: _ready ? _webView() : const CircularProgressIndicator(),
    );

    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack() == true && !_exit) {
          _controller.goBack();
          return false;
        }
        return true;
      },
      child: scaffold,
    );
  }

  Widget _webView() {
    return WebViewWidget(
      // initialUrl: 'https://r3byv.csb.app/',
      controller: _controller,
    );
  }

  void _rpcResolve(dynamic response, int id) {
    String msg = jsonEncode(response);
    debugPrint('window["resolveRpc$_realMessageHandlerKey"]($id, $msg)');
    _injectionCompleter.future.then((value) => _controller.runJavaScript('window["resolveRpc$_realMessageHandlerKey"]($id, $msg)'));
  }

  void _rpcReject(dynamic response, int id) {
    String msg = jsonEncode(response);
    _injectionCompleter.future.then((value) => _controller.runJavaScript('window["rejectRpc$_realMessageHandlerKey"]($id, $msg)'));
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class JavaScriptChannel {
  final String name;
  final void Function(JavaScriptMessage) onMessageReceived;

  JavaScriptChannel({required this.name, required this.onMessageReceived});
}