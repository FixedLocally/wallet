import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../generated/l10n.dart';

class ShowSecretRoute extends StatefulWidget {
  final String title;
  final String copySuccessMessage;
  final String secret;
  final Widget? header;

  const ShowSecretRoute({
    Key? key,
    required this.title,
    required this.copySuccessMessage,
    required this.secret,
    this.header,
  }) : super(key: key);

  @override
  State<ShowSecretRoute> createState() => _ShowSecretRouteState();
}

class _ShowSecretRouteState extends State<ShowSecretRoute> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (widget.header != null) widget.header!,
              GestureDetector(
                onTapDown: (_) {
                  setState(() {
                    _revealed = true;
                  });
                },
                onTapUp: (_) {
                  setState(() {
                    _revealed = false;
                  });
                },
                onTapCancel: () {
                  setState(() {
                    _revealed = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  margin: const EdgeInsets.only(top: 16.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).primaryColor),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 80.0),
                          child: Text(
                            _revealed ? widget.secret : S.current.tapToReveal,
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(S.current.ok),
              ),
              // copy button
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.secret));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.copySuccessMessage),
                    ),
                  );
                },
                child: Text(S.current.copy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
