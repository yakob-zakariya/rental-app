import 'package:flutter/material.dart';

/// Shows [message] in a SnackBar, replacing any one already showing. The
/// app's single ScaffoldMessenger keeps it visible across navigation (e.g.
/// after closing a screen).
void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
