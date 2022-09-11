import 'package:flutter/material.dart';

import '../../generated/l10n.dart';

class ConfirmBottomSheet extends StatelessWidget {
  final String? title;
  final String? confirmText;
  final String? cancelText;
  final WidgetBuilder bodyBuilder;

  const ConfirmBottomSheet({
    super.key,
    this.title,
    this.confirmText,
    this.cancelText,
    required this.bodyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    return SafeArea(
      child: TextButtonTheme(
        data: TextButtonThemeData(
          style: TextButton.styleFrom(
            primary: themeData.colorScheme.onPrimary,
            backgroundColor: themeData.colorScheme.primary,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(40)),
            ),
            textStyle: themeData.textTheme.button?.copyWith(
              color: themeData.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 32),
            if (title != null) ...[
              Text(title!, style: themeData.textTheme.headline6),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: bodyBuilder(context),
            ),
            SizedBox(height: 8),
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
                        cancelText ?? S.current.no,
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
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                      child: Text(confirmText ?? S.current.yes),
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
