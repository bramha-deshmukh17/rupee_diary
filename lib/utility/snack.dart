import 'package:flutter/material.dart';
import 'constant.dart';

void showSnack(String message, BuildContext context, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? kRed : kGreen,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: error ? 3 : 2),
    ),
  );
}
