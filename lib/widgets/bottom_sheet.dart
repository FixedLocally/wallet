import 'package:flutter/material.dart';

Future<int> showActionBottomSheet({
  required BuildContext context,
  required String title,
  required List<BottomSheetAction> actions,
}) async {
  int? result = await showModalBottomSheet<int>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            ...actions.map((action) => ListTile(
              title: Text(action.title),
              leading: action.leading,
// dense: true,
              onTap: () {
                Navigator.pop(ctx, action.value);
              },
            )),
          ],
        ),
      );
    },
  );
  return result ?? -1;
}

class BottomSheetAction {
  final String title;
  final Widget? leading;
  final int value;

  BottomSheetAction({
    required this.title,
    this.leading,
    required this.value,
  });
}
