import 'package:flutter/material.dart';

import 'reader_theme.dart';

/// Wraps adaptive dialogs with [ReaderThemeData] so system-styled sheets match the app theme.
Future<T?> showThemedAdaptiveDialog<T>({
  required BuildContext context,
  required ReaderThemeData theme,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showAdaptiveDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => Theme(
      data: theme.toMaterialTheme(),
      child: Builder(builder: builder),
    ),
  );
}

/// Wraps Material dialogs with [ReaderThemeData].
Future<T?> showThemedDialog<T>({
  required BuildContext context,
  required ReaderThemeData theme,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => Theme(
      data: theme.toMaterialTheme(),
      child: Builder(builder: builder),
    ),
  );
}
