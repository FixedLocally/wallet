import 'package:flutter/material.dart';

import '../../generated/l10n.dart';

class ConfirmBottomSheet extends StatefulWidget {
  final String? title;
  final String? confirmText;
  final String? cancelText;
  final WidgetBuilder bodyBuilder;
  final String? doubleConfirm;

  const ConfirmBottomSheet({
    super.key,
    this.title,
    this.confirmText,
    this.cancelText,
    this.doubleConfirm,
    required this.bodyBuilder,
  });

  @override
  State<ConfirmBottomSheet> createState() => _ConfirmBottomSheetState();
}

class _ConfirmBottomSheetState extends State<ConfirmBottomSheet> {
  late bool _confirmed;

  @override
  void initState() {
    super.initState();
    _confirmed = widget.doubleConfirm == null;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    return SafeArea(
      child: TextButtonTheme(
        data: TextButtonThemeData(
          style: TextButton.styleFrom(
            // primary: themeData.colorScheme.onPrimary,
            backgroundColor: themeData.colorScheme.primary,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(40)),
            ),
            textStyle: themeData.textTheme.labelLarge?.copyWith(
              color: themeData.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            if (widget.title != null) ...[
              Text(widget.title!, style: themeData.textTheme.titleLarge),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height / 2 - 100,
                    ),
                    child: SingleChildScrollView(child: widget.bodyBuilder(context)),
                  );
                },
              ),
            ),
            SizedBox(height: 8),
            if (widget.doubleConfirm != null) ...[
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                value: _confirmed,
                onChanged: (_) {
                  setState(() {
                    _confirmed = !_confirmed;
                  });
                },
                title: Text(widget.doubleConfirm!),
              ),
            ],
            Row(
              children: [
                SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: themeData.colorScheme.background,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      child: Text(
                        widget.cancelText ?? S.current.no,
                        style: TextStyle(
                          color: themeData.colorScheme.onBackground,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton(
                      style: _confirmed ? null : TextButton.styleFrom(
                        backgroundColor: themeData.disabledColor,
                      ),
                      onPressed: _confirmed ? () {
                        Navigator.of(context).pop(true);
                      } : null,
                      child: Text(
                        widget.confirmText ?? S.current.yes,
                        style: TextStyle(
                          color: themeData.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
